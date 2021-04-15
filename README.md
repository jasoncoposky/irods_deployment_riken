# Documentation

This document describes how to deploy the policy for Scenario 1 of the Riken Deployment detailed below.

## SCENARIO 1
```
Catalog Server : arima-bm01 on Oracle Cloud.

Tier 1 : Local Unix file system in RIKEN center. 50-100TB (DDN XFS).
Tier 2 : Oracle Object Storage (S3 compatible) or Unix File System on VM on Oracle Cloud.
	
Policies
1. Asynchronously replicated tiering is required using both tiers.
2. Accessing (create, read, and modify/delete) the user’s files is always done in Tier 1 local file system. If there is no space available in Tier 1 all writes will fail.
3. When a file is written to the Tier 1 local file storage, replication to Tier 2 should be started within several minutes.
4. When the disk usage exceeds 80%, files are automatically deleted from Tier 1 in the order of the oldest last access time.
5. User should update a files on Tier 1. If the file doesn’t exist on Tier 1, the file should be replicated from Tier 2 to Tier 1.  After the file is updated on Tier 1 the file should be replicated from Tier 1 to Tier 2 in a few minutes. 
6. Deleting should be done asynchronously. First the user should delete a file in Tier 1.  Then with several hours delay the data should be deleted from the Tier 2 - why?
7. Detects (via logs, etc)  inconsistencies at least daily such as a file existing in the catalog database but not in the Tier 1 or 2 resources. 
8. Files that have not been accessed for over a year are deleted from the Tier 1 local storage regardless of the amount of Tier 1 local storage used. 
9. To keep reliability of data, checksumming is required for every replication operation.
10. Check consistency for whole data regularly.
```

The policies are split between two different execution modes, synchronous and asynchronous.  The synchronous policy is detailed in the riken_server_config.json file under the `plugin_configuration` then `rule_engines`.  For deployment only the configuration of the new policy plugins needs copied to this section in the server in question as detailed below.  We will walk through the configuration section by section detailing the plugins and options for this configuration.

```json
        
            {
                "instance_name": "irods_rule_engine_plugin-event_handler-data_object_modified-instance",
                "plugin_name": "irods_rule_engine_plugin-event_handler-data_object_modified",
                "plugin_specific_configuration": {
                    "policies_to_invoke" : [
                        {
                            "active_policy_clauses" : ["post"],
                            "events" : ["put", "get", "create", "read", "write", "rename", "registration"],
                            "policy_to_invoke"    : "irods_policy_access_time",
                            "configuration" : {
                            }
                        },
                        {
                            "comment"  : "S1.3 : When a file is written to the Tier 1 local file storage, replication to Tier 2 should be started within several minutes.",
                            "comment2" : "S1.5 : After the file is updated on Tier 1 the file should be replicated from Tier 1 to Tier 2 in a few minutes.",

                            "active_policy_clauses" : ["post"],
                            "events" : ["put", "create", "write", "registration"],
                            "policy_to_invoke" : "irods_policy_enqueue_rule",
                            "parameters" : {
                                "delay_conditions" : "<EF>DOUBLE UNTIL SUCCESS OR 10 TIMES</EF><INST_NAME>irods_rule_engine_plugin-cpp_default_policy-instance</INST_NAME>",
                                "policy_to_invoke" : "irods_policy_execute_rule",
                                "parameters" : {
                                    "policy_to_invoke"    : "irods_policy_data_replication",
                                    "configuration" : {
                                        "source_to_destination_map" : {
                                            "tier_1" : ["tier_2"]
                                        }
                                    }
                                }
                            }
                        },
                        {
                            "comment" : "S1.5 : If the file doesn't exist on Tier 1, the file should be replicated from Tier 2 to Tier 1.",

                            "active_policy_clauses" : ["post"],
                            "events" : ["get", "write"],
                            "policy_to_invoke" : "irods_policy_data_replication",
                            "configuration" : {
                                "source_to_destination_map" : {
                                    "tier_2" : ["tier_1"]
                                }
                            }
                        },
                        {
                            "comment" : "S11.9 : To keep reliability of data, checksumming is required for every replication operation",

                            "active_policy_clauses" : ["post"],
                            "events" : ["replication"],
                            "policy_to_invoke" : "irods_policy_data_verification",
                            "configuration" : {
                            }
                        }
                    ]
                }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-access_time-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-access_time",
                "plugin_specific_configuration": {
                 }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-data_replication-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-data_replication",
                "plugin_specific_configuration": {
                 }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-data_retention-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-data_retention",
                "plugin_specific_configuration": {
                    "mode" : "trim_single_replica"
                }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-data_verification-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-data_verification",
                "plugin_specific_configuration": {
                }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-query_processor-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-query_processor",
                "plugin_specific_configuration": {
                }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-filesystem_usage-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-filesystem_usage",
                "plugin_specific_configuration": {
                }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-verify_checksum-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-verify_checksum",
                "plugin_specific_configuration": {
                }
            },
```

The first rule engine plugin configured is the Data Object Modified event handler.  This plugins will issue events for any changes to a data object as detailed [here](https://github.com/jasoncoposky/irods_rule_engine_plugins_policy/blob/master/README.md).  The `policies_to_invoke` are a series of configured policy reacting to the desired events, allowing us to configure the synchronous policy as detailed in S1.

```json
                "instance_name": "irods_rule_engine_plugin-event_handler-data_object_modified-instance",
                "plugin_name": "irods_rule_engine_plugin-event_handler-data_object_modified",
                "plugin_specific_configuration": {
                    "policies_to_invoke" : [
```

The first policy configured will update the accesss time metadata for every data object that is touched by any user, invoking `irods_policy_access_time` for every data access event: `put`, `get`, `create`, `read`, `write`, `rename`, `registration`.

```json
                        {
                            "active_policy_clauses" : ["post"],
                            "events" : ["put", "get", "create", "read", "write", "rename", "registration"],
                            "policy_to_invoke"    : "irods_policy_access_time",
                            "configuration" : {
                            }
                        },
```

The second policy configured satisfies S1 item 3 and item 5 which schedules an asynchrnous job to replicate data which lands on the resource `tier_1` to `tier_2` on the events of `put`, `create`, `write`, and `registration`.  The policy `irods_enqueue_rule` will push a rule on to the delayed execution queue, the policy `irods_execute_rule` will run a rule, and the policy `irods_policy_data_replication` handles the replication as requested.  The replication policy has a configuration parameter which is a map of source resources to an array of destination resources in `source_to_destination_map`.  Simply change `tier_1` to any desired source resource and `tier_2` to the desired destination resource in the production deployment.

```json
                        {
                            "comment"  : "S1.3 : When a file is written to the Tier 1 local file storage, replication to Tier 2 should be started within several minutes.",
                            "comment2" : "S1.5 : After the file is updated on Tier 1 the file should be replicated from Tier 1 to Tier 2 in a few minutes.",

                            "active_policy_clauses" : ["post"],
                            "events" : ["put", "create", "write", "registration"],
                            "policy_to_invoke" : "irods_policy_enqueue_rule",
                            "parameters" : {
                                "delay_conditions" : "<EF>DOUBLE UNTIL SUCCESS OR 10 TIMES</EF><INST_NAME>irods_rule_engine_plugin-cpp_default_policy-instance</INST_NAME>",
                                "policy_to_invoke" : "irods_policy_execute_rule",
                                "parameters" : {
                                    "policy_to_invoke"    : "irods_policy_data_replication",
                                    "configuration" : {
                                        "source_to_destination_map" : {
                                            "tier_1" : ["tier_2"]
                                        }
                                    }
                                }
                            }
                        },
```

The next policy configured for the Data Object Modified event handler is the policy which will stage a data object back to the `tier_1` resource should it have been trimmed from the cache tier.  This policy synchronously replicates the data back using the same policy `irods_policy_data_replication` as the previous configuration, but without the delayed execution.

```json
                        {
                            "comment" : "S1.5 : If the file doesn't exist on Tier 1, the file should be replicated from Tier 2 to Tier 1.",

                            "active_policy_clauses" : ["post"],
                            "events" : ["get", "write"],
                            "policy_to_invoke" : "irods_policy_data_replication",
                            "configuration" : {
                                "source_to_destination_map" : {
                                    "tier_2" : ["tier_1"]
                                }
                            }
                        },
````

The last synchrnous policy configured is that of data verification.  For every `replication` event within the system, the data will be verified by checksum to be correct through the invocation of the policy `irods_policy_data_verification`.  This policy is configured through metadata attached to the source resource in question.  For this deployment the metadata on both the `tier_1` and `tier_2` resources should be: `irods::verification::type checksum`.  Other options include `catalog`, and `filesystem` should a less computationally expesive option be desired.

```json
                        {
                            "comment" : "S11.9 : To keep reliability of data, checksumming is required for every replication operation",

                            "active_policy_clauses" : ["post"],
                            "events" : ["replication"],
                            "policy_to_invoke" : "irods_policy_data_verification",
                            "configuration" : {
                            }
                        }
```

And finally within this block of configuration we see the rule engine plugins which implement the event handler, as well as the policies configured within the event handler.  Thes policies could be implemented in a number of ways, but C++ rule engine plugins are provided out of the box.  Two additional plugins are included in order to satisify the asyncrnouse requirements, which will be discused next.

```json
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-access_time-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-access_time",
                "plugin_specific_configuration": {
                 }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-data_replication-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-data_replication",
                "plugin_specific_configuration": {
                 }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-data_retention-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-data_retention",
                "plugin_specific_configuration": {
                    "mode" : "trim_single_replica"
                }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-data_verification-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-data_verification",
                "plugin_specific_configuration": {
                }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-query_processor-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-query_processor",
                "plugin_specific_configuration": {
                }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-filesystem_usage-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-filesystem_usage",
                "plugin_specific_configuration": {
                }
            },
            {
                "instance_name": "irods_rule_engine_plugin-policy_engine-verify_checksum-instance",
                "plugin_name": "irods_rule_engine_plugin-policy_engine-verify_checksum",
                "plugin_specific_configuration": {
                }
            },
```
