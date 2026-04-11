# frozen_string_literal: true

module StreamWeaver
  module Resource
    # State keys owned by the resource DSL. All use the _sw_ prefix to avoid
    # collision with user-managed state. Centralized here so any rename is
    # a one-line change.
    #
    # Include this module to use RESOURCE, ACTION, ID unqualified.
    module StateKeys
      RESOURCE = :_sw_resource  # active resource name (Symbol), nil on page routes
      ACTION   = :_sw_action    # current action (:index/:show/:new/:edit/:destroy_confirm or page name sym)
      ID       = :_sw_id        # selected record id (String), nil when not applicable
    end
  end
end
