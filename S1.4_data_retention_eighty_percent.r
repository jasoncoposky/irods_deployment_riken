{
    "policy_to_invoke" : "irods_policy_enqueue_rule",
    "parameters" : {

        "comment" : "S1.4 : When the disk usage exceeds 80%, files are automatically deleted from Tier 1 in the order of the oldest last access time",

        "delay_conditions" : "<EF>REPEAT FOR EVER</EF><INST_NAME>irods_rule_engine_plugin-cpp_default_policy-instance</INST_NAME>",
        "policy_to_invoke" : "irods_policy_execute_rule",
        "parameters" : {
            "policy_to_invoke"  : "irods_policy_query_processor",
            "parameters" : {
                "stop_on_error" : "true",
                "query_string"  : "tier_1_archive_query",
                "query_limit"   : 1000,
                "query_type"    : "specific",
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
