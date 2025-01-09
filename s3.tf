## ALB Logs bucket
resource "aws_s3_bucket" "alb_logs_bucket" {
  bucket        = "alb-logs-bucket-${data.aws_caller_identity.current.account_id}-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "alb_logs_bucket_block" {
  bucket                  = aws_s3_bucket.alb_logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "alb_logs_bucket_versioning" {
  bucket = aws_s3_bucket.alb_logs_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "alb_logs_bucket_policy" {
  bucket = aws_s3_bucket.alb_logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${local.elb_account_id}:root"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.alb_logs_bucket.arn}/alb-logs/AWSLogs/${local.aws_account_id}/*",
      }
    ]
  })
}

## Configs bucket
resource "aws_s3_bucket" "configs_bucket" {
  bucket        = "configs-bucket-${data.aws_caller_identity.current.account_id}-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "configs_bucket_block" {
  bucket                  = aws_s3_bucket.configs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "configs_bucket_versioning" {
  bucket = aws_s3_bucket.configs_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "config_and_reg_files" {
  for_each = local.config_and_reg_files

  bucket       = aws_s3_bucket.configs_bucket.id
  key          = each.key
  content      = each.value
  content_type = "text/yaml"
  acl          = "private"
  etag         = md5(each.value)
  depends_on   = [aws_sfn_state_machine.ecs_manager_state_machine]
}

resource "aws_s3_bucket_notification" "configs_bucket_to_eventbridge" {
  bucket      = aws_s3_bucket.configs_bucket.id
  eventbridge = true
}

resource "aws_s3_bucket_policy" "configs_bucket_policy" {
  bucket = aws_s3_bucket.configs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowServicesSGAccess"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.services_role.arn,
            aws_iam_role.datasync_role.arn
          ]
        }
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = [
          "${aws_s3_bucket.configs_bucket.arn}",
          "${aws_s3_bucket.configs_bucket.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:sourceVpce" : aws_vpc_endpoint.s3_endpoint.id
          }
        }
      }
    ]
  })
}
