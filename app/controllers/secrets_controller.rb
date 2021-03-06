# frozen_string_literal: true

class SecretsController < RestController
  include FindResource
  include AuthorizeResource
  
  before_filter :current_user
  before_filter :find_resource, except: [:batch]
  
  def create
    authorize :update
    
    value = request.raw_post

    raise ArgumentError, "'value' may not be empty" if value.blank?

    Secret.create resource_id: @resource.id, value: value
    @resource.enforce_secrets_version_limit

    head :created
  ensure
    Audit::Event::Update.new_with_exception(
      resource: @resource,
      user: @current_user
    ).log_to Audit.logger
  end
  
  def show
    authorize :execute
    
    version = params[:version]
    secret = if version.is_a?(String) && version.to_i.to_s == version
      @resource.secrets.find{|s| s.version == version.to_i}
    elsif version.nil?
      @resource.secrets.last
    else
      raise ArgumentError, "invalid type for parameter 'version'"
    end
    raise Exceptions::RecordNotFound.new(@resource.id, message: "Requested version does not exist") if secret.nil?
    value = secret.value

    mime_type = if ( a = @resource.annotations_dataset.select(:value).where(name: 'conjur/mime_type').first )
      a[:value]
    end
    mime_type ||= 'application/octet-stream'

    send_data value, type: mime_type
  ensure
    audit_fetch @resource, version: version
  end

  def batch
    raise ArgumentError, 'variable_ids' if params[:variable_ids].blank?

    variable_ids = params[:variable_ids].split(',').compact

    raise ArgumentError, 'variable_ids' if variable_ids.blank?
    
    variables = Resource.where(resource_id: variable_ids).eager(:secrets).all

    unless variable_ids.count == variables.count
      raise Exceptions::RecordNotFound,
            variable_ids.find { |r| !variables.map(&:id).include?(r) }
    end
    
    result = {}

    authorize_many variables, :execute
    
    variables.each do |variable|
      if variable.secrets.last.nil?
        raise Exceptions::RecordNotFound, variable.resource_id
      end
      
      result[variable.resource_id] = variable.secrets.last.value
      audit_fetch variable
    end

    render json: result
  end

  def audit_fetch resource, version: nil
    Audit::Event::Fetch.new_with_exception(
      resource: resource,
      version: version,
      user: current_user
    ).log_to Audit.logger
  end

  # NOTE: We're following REST/http semantics here by representing this as 
  #       an "expirations" that you POST to you.  This may seem strange given
  #       that what we're doing is simply updating an attribute on a secret.
  #       But keep in mind this purely an implementation detail -- we could 
  #       have implemented expirations in many ways.  We want to expose the
  #       concept of an "expiration" to the user.  And per standard rest, 
  #       we do that with a resource, "expirations."  Expiring a variable
  #       is then a matter of POSTing to create a new "expiration" resource.
  #       
  #       It is irrelevant that the server happens to implement this request
  #       by assigning nil to `expires_at`.
  #
  #       Unfortuneatly, to be consistent with our other routes, we're abusing
  #       query strings to represent what is in fact a new resource.  Ideally,
  #       we'd use a slash instead, but decided that consistency trumps 
  #       correctness in this case.
  #
  def expire
    authorize :update
    Secret.update_expiration(@resource.id, nil)
    head :created
  end
end
