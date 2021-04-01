{
    "policy_to_invoke" : "irods_policy_enqueue_rule",
    "parameters" : {

        "comment" : "S1.8 : Files that have not been accessed for over a year are deleted from the Tier 1 local storage regardless of the amount of Tier 1 local storage used.",

        "delay_conditions" : "<PLUSET>1s</PLUSET><EF>REPEAT FOR EVER</EF><INST_NAME>irods_rule_engine_plugin-cpp_default_policy-instance</INST_NAME>",
        "policy_to_invoke" : "irods_policy_execute_rule",
        "parameters" : {
            "policy_to_invoke"    : "irods_policy_query_processor",
            "parameters" : {
                "lifetime"      : 60,
                "stop_on_error" : "true",
                "query_string"  : "SELECT USER_NAME, COLL_NAME, DATA_NAME, RESC_NAME WHERE RESC_NAME = 'tier_1' AND META_DATA_ATTR_NAME = 'irods::access_time' AND META_DATA_ATTR_VALUE < 'IRODS_TOKEN_LIFETIME_END_TOKEN'",
                "query_limit"   : 1000,
                "query_type"    : "general",
                "number_of_threads" : 4,
                "policies_to_invoke" : [
                    {
                        "policy_to_invoke"    : "irods_policy_data_verification",
                        "parameters" : {
                            "source_resource" : "tier_1",
                            "destination_resource" : "tier_2"
                        }
                    },
                    {
                        "policy_to_invoke"    : "irods_policy_data_retention",
                        "configuration" : {
                            "source_to_destination_map" : {
                                "mode" : "trim_single_replica",
                                "resource_white_list" : ["tier_1"]
                            }
                        }
                    }
                ]
            }
        }
    }
}
INPUT null
OUTPUT ruleExecOut
