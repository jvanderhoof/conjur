Feature: RBAC privileges control whether a role can update and/or fetch a secret.

  Background:
    Given I create a new user "bob"
    And I create a new "variable" resource called "probe"
    And I permit user "bob" to "read" it
    And I create 1 secret values

  Scenario: Fetching a secret as an unauthorized user results in a 403 error.

    Given I login as "bob"
    When I GET "/secrets/cucumber/:resource_kind/:resource_id"
    Then the HTTP response status code is 403
    And there is an audit record matching:
    """
      <36>1 * * conjur * fetch
      [auth@43868 user="cucumber:user:bob"]
      [subject@43868 resource="cucumber:variable:probe"]
      [action@43868 operation="fetch" result="failure"]
      cucumber:user:bob tried to fetch cucumber:variable:probe: Forbidden
    """

  Scenario: Updating a secret as an unauthorized user results in a 403 error.

    Given I login as "bob"
    When I POST "/secrets/cucumber/:resource_kind/:resource_id" with parameters:
    """
    v-1
    """
    Then the HTTP response status code is 403
    And there is an audit record matching:
    """
      <36>1 * * conjur * update
      [auth@43868 user="cucumber:user:bob"]
      [subject@43868 resource="cucumber:variable:probe"]
      [action@43868 operation="update" result="failure"]
      cucumber:user:bob tried to update cucumber:variable:probe: Forbidden
    """

  Scenario: A foreign role can be granted permission to fetch a secret.

    The `execute` privilege can be granted to any role to allow it to fetch a secret.

    Given I permit user "bob" to "execute" it
    And I login as "bob"
    Then I can GET "/secrets/cucumber/:resource_kind/:resource_id"

  Scenario: A foreign role can be granted permission to update a secret.

    The `update` privilege can be granted to any role to allow it to update a secret.
 
    Given I permit user "bob" to "update" it
    When I login as "bob"
    Then I can POST "/secrets/cucumber/:resource_kind/:resource_id" with parameters:
    """
    v-1
    """

  Scenario: Fetching a secret without any permission on it
    If the user doesn't have any permission or ownership of a secret, fetching
    it should return 404 (not 403) even if it exists.

    Given I create a new user "alice"
    And I login as "alice"

    When I GET "/secrets/cucumber/:resource_kind/:resource_id"
    Then the HTTP response status code is 404
    And there is an audit record matching:
    """
      <36>1 * * conjur * fetch
      [auth@43868 user="cucumber:user:alice"]
      [subject@43868 resource="cucumber:variable:probe"]
      [action@43868 operation="fetch" result="failure"]
      cucumber:user:alice tried to fetch cucumber:variable:probe: Forbidden
    """
