Feature: Adding and fetching secrets

  Each resource in Conjur has an associated list of "secrets", each of which is
  an arbitrary piece of encrypted data. Access to secrets is governed by
  privileges:

  - **execute** permission to fetch the value of a secret
  - **update** permission to change the value of a secret

  The list of secrets on a resource is appended when a new secret value is
  added. The list is capped to the last 20 secret values in order to limit the
  size of the backend database.

  Secrets are encrypted using AES-256-GCM.

  Background:
    Given I am a user named "eve"
    Given I create a new "variable" resource called "probe"

  Scenario: Fetching a resource with no secret values returna a 404 error.

    When I GET "/secrets/cucumber/variable/probe"
    Then the HTTP response status code is 404

  Scenario: The 'conjur/mime_type' annotation is used in the value response.

    If the annotation `conjur/mime_type` exists on a resource, then when a
    secret value is fetched from the resource, that mime type is used as the
    `Content-Type` header in the response. 

    Given I set annotation "conjur/mime_type" to "application/json"
    And I successfully POST "/secrets/cucumber/variable/probe" with body:
    """
    [ "v-1" ]
    """
    Then there is an audit record matching:
    """
      <37>1 * * conjur * update
      [auth@43868 user="cucumber:user:eve"]
      [subject@43868 resource="cucumber:variable:probe"]
      [action@43868 operation="update" result="success"]
      cucumber:user:eve updated cucumber:variable:probe
    """
    When I successfully GET "/secrets/cucumber/variable/probe"
    Then the JSON should be:
    """
    [ "v-1" ]
    """

  Scenario: Secrets can contain any binary data.

    Given I create a binary secret value
    When I successfully GET "/secrets/cucumber/variable/probe"
    Then the binary result is preserved

  Scenario: The last secret is the default one returned.

    Adding a new secret appends to a list of values on the resource. When
    retrieving secrets, the last value in the list is returned by default.

    Given I successfully POST "/secrets/cucumber/variable/probe" with body:
    """
    v-1
    """
    And I successfully POST "/secrets/cucumber/variable/probe" with body:
    """
    v-2
    """
    When I successfully GET "/secrets/cucumber/variable/probe"
    Then the binary result is "v-2"
    And there is an audit record matching:
    """
      <38>1 * * conjur * fetch
      [auth@43868 user="cucumber:user:eve"]
      [subject@43868 resource="cucumber:variable:probe"]
      [action@43868 operation="fetch" result="success"]
      cucumber:user:eve fetched cucumber:variable:probe
    """

  Scenario: When fetching a secret, a specific secret index can be specified.

    The `version` parameter can be used to select a specific secret value from
    the list.

    Given I successfully POST "/secrets/cucumber/variable/probe" with body:
    """
    v-1
    """
    And I successfully POST "/secrets/cucumber/variable/probe" with body:
    """
    v-2
    """
    When I successfully GET "/secrets/cucumber/variable/probe?version=1"
    Then the binary result is "v-1"
    And there is an audit record matching:
    """
      <38>1 * * conjur * fetch
      [auth@43868 user="cucumber:user:eve"]
      [subject@43868 resource="cucumber:variable:probe" version="1"]
      [action@43868 operation="fetch" result="success"]
      cucumber:user:eve fetched version 1 of cucumber:variable:probe
    """

  Scenario: Fetching with a non-existant secret version returns a 404 error.

    Given I successfully POST "/secrets/cucumber/variable/probe" with body:
    """
    v-1
    """
    When I GET "/secrets/cucumber/variable/probe?version=2"
    Then the HTTP response status code is 404

  Scenario: When creating a secret, the value parameter is required.

    When I POST "/secrets/cucumber/variable/probe" with body:
    """
    """
    Then the HTTP response status code is 422

  Scenario: Only the last 20 versions of a secret are stored.
  
    Given I create 20 secret values
    And I successfully POST "/secrets/cucumber/variable/probe" with body:
    """
    v-21
    """
    When I GET "/secrets/cucumber/variable/probe?version=1"
    Then the HTTP response status code is 404
