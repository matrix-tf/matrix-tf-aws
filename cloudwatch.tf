## ECS
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "ecs-logs"
  retention_in_days = 30
}

## EventBridge
resource "aws_cloudwatch_log_group" "eventbridge_log_group" {
  name              = "eventbridge-logs"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_resource_policy" "eventbridge_log_policy" {
  policy_name = "eventbridge-log-permissions"

  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Principal : {
          Service : "events.amazonaws.com"
        },
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.eventbridge_log_group.arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "configs_bucket_event_rule" {
  name        = "configs-bucket-change"
  description = "Detect changes to Configs bucket"

  event_pattern = jsonencode({
    source = ["aws.s3"]
    detail-type = [
      "Object Created",
      "Object Deleted",
      "Delete Marker Created"
    ]
    detail = {
      bucket = {
        name = [aws_s3_bucket.configs_bucket.bucket]
      },
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_manager_state_machine_target" {
  rule      = aws_cloudwatch_event_rule.configs_bucket_event_rule.name
  target_id = "ecs-manager-state-machine-target"
  arn       = aws_sfn_state_machine.ecs_manager_state_machine.arn
  role_arn  = aws_iam_role.ecs_manager_state_machine_role.arn

  retry_policy {
    maximum_retry_attempts       = 10
    maximum_event_age_in_seconds = 3600
  }

  dead_letter_config {
    arn = aws_sqs_queue.ecs_manager_state_machine_dlq.arn
  }
}

resource "aws_cloudwatch_event_target" "eventbridge_log_target" {
  rule      = aws_cloudwatch_event_rule.configs_bucket_event_rule.name
  target_id = "eventbridge-logs"
  arn       = aws_cloudwatch_log_group.eventbridge_log_group.arn
}
