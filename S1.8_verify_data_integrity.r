{
    "policy_to_invoke" : "irods_policy_enqueue_rule",
    "parameters" : {

        "comment" : "S1.8 : Files that have not been accessed for over a year are deleted from the Tier 1 local storage regardless of the amount of Tier 1 local storage used.",

        "delay_conditions" : "<PLUSET>1s</PLUSET><EF>REPEAT FOR EVER</EF><INST_NAME>irods_rule_engine_plugin-cpp_default_policy-instance</INST_NAME>",
        "policy_to_invoke" : "irods_policy_execute_rule",
        "parameters" : {
            "policy_to_invoke"    : "irods_policy_query_processor",
            "parameters" : {
                "query_string"  : "SELECT USER_NAME, COLL_NAME, DATA_NAME, RESC_NAME WHERE RESC_NAME like 'tier_%'",
                "query_limit"   : 0,
                "query_type"    : "general",
                "number_of_threads" : 1,
                "policies_to_invoke" : [
                    {
                        "policy_to_invoke" : "irods_policy_verify_checksum",
                        "configuration" : {
                            "log_errors" : "true"
                        }
                    }
                ]
            }
        }
    }
}
INPUT null
OUTPUT ruleExecOut
