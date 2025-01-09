resource "aws_sfn_state_machine" "ecs_manager_state_machine" {
  name     = "ecs-manager-state-machine"
  role_arn = aws_iam_role.ecs_manager_state_machine_role.arn

  definition = jsonencode({
    Comment = "State machine to start DataSync task & sync Configs bucket directories to ECS services",
    StartAt = "StartDataSyncTask",
    States = {
      StartDataSyncTask = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:datasync:startTaskExecution",
        Parameters = {
          TaskArn = aws_datasync_task.s3_to_efs_task.arn
        },
        ResultSelector = {
          "TaskExecutionArn.$" = "$.TaskExecutionArn"
        },
        ResultPath = "$.TaskExecution",
        Catch = [
          {
            ErrorEquals = ["States.ALL"],
            ResultPath  = "$.error",
            Next        = "SendErrorToSqs"
          }
        ],
        Next = "PollDataSyncTask"
      },
      PollDataSyncTask = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:datasync:describeTaskExecution",
        Parameters = {
          "TaskExecutionArn.$" = "$.TaskExecution.TaskExecutionArn"
        },
        TimeoutSeconds = 300,
        ResultPath     = "$.TaskStatus",
        Catch = [
          {
            ErrorEquals = ["States.Timeout"],
            ResultPath  = "$.error",
            Next        = "SendErrorToSqs"
          },
          {
            ErrorEquals = ["States.ALL"],
            ResultPath  = "$.error",
            Next        = "SendErrorToSqs"
          }
        ]
        Next = "CheckTaskCompletion",
      },
      CheckTaskCompletion = {
        Type = "Choice",
        Choices = [
          {
            Variable     = "$.TaskStatus.Status",
            StringEquals = "SUCCESS",
            Next         = "ListEcsServices"
          },
          {
            Variable     = "$.TaskStatus.Status",
            StringEquals = "ERROR",
            Next         = "SendErrorToSqs"
          }
        ],
        Default = "WaitBeforeRetry"
      },
      WaitBeforeRetry = {
        Type    = "Wait",
        Seconds = 5,
        Next    = "PollDataSyncTask"
      },
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
                "ServiceArn.$"  = "$",
                "ServiceName.$" = "States.ArrayGetItem(States.StringSplit(States.ArrayGetItem(States.StringSplit(States.JsonToString($), '/'), 2), '\"'), 0)"
              },
              ResultPath = "$",
              End        = true
            },
          }
        },
        ResultSelector = {
          "ECS" = {
            "ServiceArns.$"  = "$[*].ServiceArn"
            "ServiceNames.$" = "$[*].ServiceName"
          }
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
        ItemsPath      = "$.ECS.ServiceNames",
        MaxConcurrency = 2,
        Iterator = {
          StartAt = "StopService",
          States = {
            StopService = {
              Type     = "Task",
              Resource = "arn:aws:states:::aws-sdk:ecs:updateService",
              Parameters = {
                Cluster      = aws_ecs_cluster.main.name,
                Service      = "$",
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
        ItemsPath = "$.ECS.ServiceNames",
        ItemSelector = {
          "ServiceName.$"   = "$$.Map.Item.Value",
          "S3Directories.$" = "$.S3.Directories"
        },
        MaxConcurrency = 2,
        Iterator = {
          StartAt = "FormatServiceName",
          States = {
            FormatServiceName = {
              Type = "Pass",
              Parameters = {
                "ServiceName.$" : "$.ServiceName",
                "S3Directories.$" : "$.S3Directories",
                "FormattedServiceName.$" = "States.Format('{}/', States.ArrayGetItem(States.StringSplit($.ServiceName, '-'), 0))"
              },
              ResultPath = "$",
              Next       = "CheckForConfigs",
            },
            CheckForConfigs = {
              Type = "Pass",
              Parameters = {
                "ServiceName.$" : "$.ServiceName",
                "S3Directories.$" : "$.S3Directories",
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
                  Next          = "StartEcsService"
                }
              ],
              Default = "StopEcsService"
            },
            StartEcsService = {
              Type     = "Task",
              Resource = "arn:aws:states:::aws-sdk:ecs:updateService",
              Parameters = {
                Cluster      = aws_ecs_cluster.main.name,
                "Service.$"  = "$.ServiceName",
                DesiredCount = 1
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
            StopEcsService = {
              Type     = "Task",
              Resource = "arn:aws:states:::aws-sdk:ecs:updateService",
              Parameters = {
                Cluster      = aws_ecs_cluster.main.name,
                "Service.$"  = "$.ServiceName",
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
                "error.$" : "$.error"
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
            "Error" : {
              "Cause.$" : "$.error.Cause",
              "Error.$" : "$.error.Error"
            },
            "ExecutionId.$" : "$$.Execution.Id",
            "Timestamp.$" : "$$.State.EnteredTime",
            "FailedState.$" : "$$.State.Name",
          }
        },
        End = true,
      },
    }
  })
}
