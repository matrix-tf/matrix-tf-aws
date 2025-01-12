## Services
resource "aws_iam_role" "services_role" {
  name = "services-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Effect" : "Allow",
      }
    ]
  })
}

resource "aws_iam_role_policy" "services_policy" {
  role = aws_iam_role.services_role.name
  name = "services-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListObjectsV2",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.configs_bucket.arn}",
          "${aws_s3_bucket.configs_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.ecs_log_group.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = concat(
          [aws_db_instance.matrix_db.master_user_secret[0].secret_arn],
          values(aws_secretsmanager_secret.profile_user_password)[*].arn
        )
      }
    ]
  })
}

## ECS State Machine
resource "aws_iam_role" "ecs_manager_state_machine_role" {
  name = "ecs-manager-state-machine-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
            "states.amazonaws.com",
            "events.amazonaws.com"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_manager_state_machine_policy" {
  role = aws_iam_role.ecs_manager_state_machine_role.name
  name = "ecs-manager-state-machine-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "sqs:SendMessage",
          "ecs:ListServices",
          "ecs:UpdateService",
          "states:StartExecution"
        ],
        Resource = [
          aws_sqs_queue.ecs_manager_state_machine_dlq.arn,
          aws_sfn_state_machine.ecs_manager_state_machine.arn,
          aws_s3_bucket.configs_bucket.arn,
          "${aws_s3_bucket.configs_bucket.arn}/*",
          aws_ecs_cluster.main.arn,
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.main.name}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface"
        ],
        "Resource" : "*"
      }
    ]
  })
}
