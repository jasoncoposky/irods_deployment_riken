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

The asynchronous policy is satisifed by one of four rule which will be invoked from the command line.  Thes rule push jobs on to the delayed execution queue, which will run for ever.  The first rule is found in the file `S1.4_resource_freespace_monitor.r`.  This rule will watch a storage resources vault in order to calculate the file system usage.  The percentage of storage used is then applied as metadata to the storage resource `irods::resource::filesystem_percent_used`.  This metadata value is used by an additional rule detailed later.

```
{
    "comment" : "S1.4 : When the disk usage exceeds 80%, files are automatically deleted from Tier 1 in the order of the oldest last access time",

    "policy_to_invoke" : "irods_policy_enqueue_rule",
    "parameters" : {
        "comment"          : "Set the PLUSET value to the interval desired to run the rule",
        "delay_conditions" : "<PLUSET>10s</PLUSET><EF>REPEAT FOR EVER</EF><INST_NAME>irods_rule_engine_plugin-cpp_default_policy-instance</INST_NAME>",
        "policy_to_invoke" : "irods_policy_execute_rule",
        "parameters" : {
            "policy_to_invoke"    : "irods_policy_filesystem_usage",
            "parameters" : {
                "source_resource" : "tier_1"
            }
        }
    }
}
INPUT null
OUTPUT ruleExecOut
```

We can see in the `delay_conditions` section of the policy the tag `<PLUSET>` which is short for `Plus Execution Time`, currently set to ten seconds.  This value should be set for the produciton deployment to a more coarse grained value in order to free up both file system activity as well as CPU usage.  The policy `irods_policy_filesystem_usage` has a configuration parameter of `source_resource`.  This value should be set to the resource name which is to be monitored.

The file `S1.4_data_retention_eighty_percent.r` contains the second half of the effort to identify data objects on a filesystem which has exceeded a threshold of usage.  This policy relies on a configured specific SQL query stored in the iRODS catalog and found in the file `archive_specific_query.sh`.  This policy periodically runs this query to find data objects which need to be moved from `tier_1` to `tier_2` per this policy.  The threshold for this policy is set via metadata on the storage resource in question.  In this instance `tier_1` will have a metadata tag of `irods::resource::threshold_percent` with a value holding the percentage threshold in question.  Once an object is identified, two policies are sequentially invoked.  The first `irods_data_verification` will guarantee that the data object in question from `source_resource` `tier_1` has a valid replica on `destination_resource` `tier_2` with a valid checksum, as configured by resource metadata which has been explained above.  Thes resource names shold be changed to the appropriat values in the production deployment.  If this check fails, then the second policy is not invoked due to the `stop_on_error` flag set to `true`.  Assuming the verifiation succeeds, the scond policy will trim the single replica from `tier_1`.  The `mode` optoin for `irods_policy_data_retention` has values of `trim_single_replica` or `remove_all_replicas`.  In this deployment we wish to simply remove the single replica from `tier_1`.

```
{
    "policy_to_invoke" : "irods_policy_enqueue_rule",
    "parameters" : {

        "comment" : "S1.4 : When the disk usage exceeds 80%, files are automatically deleted from Tier 1 in the order of the oldest last access time",

        "delay_conditions" : "<PLUSET>20s</PLUSET><EF>REPEAT FOR EVER</EF><INST_NAME>irods_rule_engine_plugin-cpp_default_policy-instance</INST_NAME>",
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
```

