resource "aws_sfn_state_machine" "ecs_manager_state_machine" {
  name     = "ecs-manager-state-machine"
  role_arn = aws_iam_role.ecs_manager_state_machine_role.arn

  definition = jsonencode({
    Comment = "State machine to start and stop ECS services",
    StartAt = "ListEcsServices",
    States = {
      ListEcsServices = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:ecs:listServices",
        Parameters = {
          Cluster = aws_ecs_cluster.main.name
        },
        ResultPath = "$.ECS",
        Catch = [
          {
            ErrorEquals = ["States.ALL"],
            ResultPath  = "$.error",
            Next        = "SendErrorToSqs"
          }
        ],
        Next = "HandleEmptyServices",
      },
      HandleEmptyServices = {
        Type = "Choice",
        Choices = [
          {
            Variable = "$.ECS.ServiceArns",
            IsNull   = true,
            Next     = "NoEcsServices"
          },
        ],
        Default = "ExtractServiceNames"
      },
      NoEcsServices = {
        Type  = "Fail",
        Error = "NoEcsServices",
        Cause = "No ECS services found in the cluster."
      },
      ExtractServiceNames = {
        Type      = "Map",
        ItemsPath = "$.ECS.ServiceArns",
        Iterator = {
          StartAt = "SplitArn",
          States = {
            SplitArn = {
              Type = "Pass",
              Parameters = {
                "Arn.$"  = "$",
                "Name.$" = "States.ArrayGetItem(States.StringSplit(States.ArrayGetItem(States.StringSplit(States.JsonToString($), '/'), 2), '\"'), 0)"
              },
              ResultPath = "$",
              End        = true
            },
          }
        },
        ResultSelector = {
          "EcsServices.$" = "$[*]"
        },
        ResultPath = "$",
        Next       = "ListS3Directories"
      },
      ListS3Directories = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:s3:listObjectsV2",
        Parameters = {
          Bucket    = aws_s3_bucket.configs_bucket.bucket,
          Prefix    = "",
          Delimiter = "/"
        },
        ResultSelector = {
          "Directories.$" = "$.CommonPrefixes[*].Prefix"
        },
        ResultPath = "$.S3",
        Catch = [
          {
            ErrorEquals = ["States.ALL"],
            ResultPath  = "$.error",
            Next        = "SendErrorToSqs"
          }
        ],
        Next = "HandleEmptyS3",
      },
      HandleEmptyS3 = {
        Type = "Choice",
        Choices = [
          {
            Variable = "$.S3.Directories",
            IsNull   = false,
            Next     = "CompareAndUpdateServices"
          },
        ],
        Default = "StopAllEcsServices"
      },
      StopAllEcsServices = {
        Type           = "Map",
        ItemsPath      = "$.EcsServices",
        MaxConcurrency = 2,
        Iterator = {
          StartAt = "StopService",
          States = {
            StopService = {
              Type     = "Task",
              Resource = "arn:aws:states:::aws-sdk:ecs:updateService",
              Parameters = {
                Cluster      = aws_ecs_cluster.main.name,
                Service      = "$.Name",
                DesiredCount = 0
              },
              End = true
            }
          }
        },
        End = true
      },
      CompareAndUpdateServices = {
        Type      = "Map",
        ItemsPath = "$.EcsServices",
        ItemSelector = {
          "Service.$"       = "$$.Map.Item.Value",
          "S3Directories.$" = "$.S3.Directories"
        },
        MaxConcurrency = 2,
        Iterator = {
          StartAt = "FormatServiceName",
          States = {
            FormatServiceName = {
              Type = "Pass",
              Parameters = {
                "Service.$"              = "$.Service",
                "S3Directories.$"        = "$.S3Directories",
                "FormattedServiceName.$" = "States.Format('{}/', States.ArrayGetItem(States.StringSplit($.Service.Name, '-'), 0))"
              },
              ResultPath = "$",
              Next       = "CheckForConfigs",
            },
            CheckForConfigs = {
              Type = "Pass",
              Parameters = {
                "Service.$"              = "$.Service",
                "S3Directories.$"        = "$.S3Directories",
                "FormattedServiceName.$" = "$.FormattedServiceName"
                "ConfigsPresent.$"       = "States.ArrayContains($.S3Directories, $.FormattedServiceName)"
              },
              ResultPath = "$",
              Next       = "CompareConfigsCheck",
            },
            CompareConfigsCheck = {
              Type = "Choice",
              Choices = [
                {
                  Variable      = "$.ConfigsPresent"
                  BooleanEquals = true
                  Next          = "ListFiles"
                }
              ],
              Default = "StopEcsService"
            },
            ListFiles = {
              Type     = "Task",
              Resource = "arn:aws:states:::aws-sdk:s3:listObjectsV2",
              Parameters = {
                Bucket     = aws_s3_bucket.configs_bucket.bucket
                "Prefix.$" = "$.FormattedServiceName"
              },
              ResultSelector = {
                "Files.$" = "$.Contents[*].Key"
              },
              ResultPath = "$.ServiceFiles",
              Next       = "InitializeCombinedETags"
            },
            InitializeCombinedETags = {
              Type = "Pass",
              Parameters = {
                "Service.$"              = "$.Service",
                "S3Directories.$"        = "$.S3Directories",
                "FormattedServiceName.$" = "$.FormattedServiceName",
                "ConfigsPresent.$"       = "$.ConfigsPresent",
                "ServiceFiles.$"         = "$.ServiceFiles.Files",
                "CombinedETags"          = ""
              },
              Next = "HashServiceFiles"
            },
            HashServiceFiles = {
              Type      = "Map",
              ItemsPath = "$.ServiceFiles",
              ItemSelector = {
                "Key.$"           = "$$.Map.Item.Value",
                "CombinedETags.$" = "$.CombinedETags"
              },
              MaxConcurrency = 10,
              Iterator = {
                StartAt = "GetFileETag",
                States = {
                  GetFileETag = {
                    Type     = "Task",
                    Resource = "arn:aws:states:::aws-sdk:s3:headObject",
                    Parameters = {
                      Bucket  = aws_s3_bucket.configs_bucket.bucket,
                      "Key.$" = "$.Key"
                    },
                    ResultSelector = {
                      "ETag.$" = "$.ETag"
                    },
                    ResultPath = "$.FileETag",
                    Catch = [
                      {
                        ErrorEquals = ["States.ALL"],
                        ResultPath  = "$.error",
                        Next        = "HandleS3Error"
                      }
                    ],
                    Next = "AccumulateETags"
                  },
                  AccumulateETags = {
                    Type = "Pass",
                    Parameters = {
                      "CombinedETags.$" = "States.Format('{}{}', $.CombinedETags, $.FileETag.ETag)"
                    },
                    ResultPath = "$.CombinedETags",
                    End        = true
                  },
                  HandleS3Error = {
                    Type = "Pass",
                    Parameters = {
                      "error.$" = "$.error"
                    },
                    End = true
                  }
                }
              },
              ResultPath = "$.CurrentHash",
              Next       = "ComputeCombinedHash"
            },
            ComputeCombinedHash = {
              Type = "Pass",
              Parameters = {
                "CombinedHash.$" = "States.Hash($.CombinedETags, 'SHA-256')"
              },
              ResultPath = "$.CurrentHash",
              Next       = "GetServiceTags"
            },
            GetServiceTags = {
              Type     = "Task",
              Resource = "arn:aws:states:::aws-sdk:ecs:listTagsForResource",
              Parameters = {
                "ResourceArn.$" : "$.Service.Arn"
              },
              ResultSelector = {
                "Tags.$" : "$.Tags[*]"
              },
              ResultPath = "$.ServiceTags",
              Catch = [
                {
                  ErrorEquals = ["States.ALL"],
                  ResultPath  = "$.error",
                  Next        = "HandleServiceError"
                }
              ],
              Next = "CheckConfigChange"
            },
            CheckConfigChange = {
              Type = "Choice",
              Choices = [
                {
                  Variable     = "$.CurrentHash.CombinedHash",
                  StringEquals = "$.ServiceDetails.Tags[?(@.key=='ConfigsHash')].value",
                  Next         = "SkipServiceUpdate"
                }
              ],
              Default = "UpdateService"
            },
            UpdateService = {
              Type     = "Task",
              Resource = "arn:aws:states:::aws-sdk:ecs:updateService",
              Parameters = {
                Cluster            = aws_ecs_cluster.main.name,
                "Service.$"        = "$.Service.Name",
                DesiredCount       = 1,
                ForceNewDeployment = true
              },
              ResultSelector = {
                "Count.$" : "$.Service.DesiredCount"
              },
              ResultPath = "$.DesiredCount"
              Catch = [
                {
                  ErrorEquals = ["States.ALL"],
                  ResultPath  = "$.error",
                  Next        = "HandleServiceError"
                }
              ],
              Next = "TagService"
            },
            TagService = {
              Type     = "Task",
              Resource = "arn:aws:states:::aws-sdk:ecs:tagResource",
              Parameters = {
                "ResourceArn.$" = "$.Service.Arn",
                Tags = [
                  {
                    Key       = "ConfigsHash",
                    "Value.$" = "$.CurrentHash.CombinedHash"
                  }
                ]
              },
              Catch = [
                {
                  ErrorEquals = ["States.ALL"],
                  ResultPath  = "$.error",
                  Next        = "HandleServiceError"
                }
              ],
              End = true
            },
            SkipServiceUpdate = {
              Type = "Pass",
              End  = true
            },
            StopEcsService = {
              Type     = "Task",
              Resource = "arn:aws:states:::aws-sdk:ecs:updateService",
              Parameters = {
                Cluster      = aws_ecs_cluster.main.name,
                "Service.$"  = "$.Service.Name",
                DesiredCount = 0
              },
              Catch = [
                {
                  ErrorEquals = ["States.ALL"],
                  ResultPath  = "$.error",
                  Next        = "HandleServiceError"
                }
              ],
              End = true,
            },
            HandleServiceError = {
              Type = "Pass",
              Parameters = {
                "error.$" = "$.error"
              },
              End = true
            }
          }
        },
        Catch = [
          {
            ErrorEquals = ["States.ALL"],
            ResultPath  = "$.error",
            Next        = "SendErrorToSqs"
          }
        ],
        End = true,
      },
      SendErrorToSqs = {
        Type     = "Task",
        Resource = "arn:aws:states:::sqs:sendMessage",
        Parameters = {
          QueueUrl = aws_sqs_queue.ecs_manager_state_machine_dlq.url,
          MessageBody = {
            Error = {
              "Cause.$" = "$.error.Cause",
              "Error.$" = "$.error.Error"
            },
            "ExecutionId.$" = "$$.Execution.Id",
            "Timestamp.$"   = "$$.State.EnteredTime",
            "FailedState.$" = "$$.State.Name",
          }
        },
        End = true,
      },
    }
  })
}
