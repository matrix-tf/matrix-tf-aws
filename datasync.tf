resource "aws_datasync_location_s3" "s3_location" {
  s3_bucket_arn = aws_s3_bucket.configs_bucket.arn
  subdirectory  = "/"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_role.arn
  }
}

resource "aws_datasync_location_efs" "efs_location" {
  efs_file_system_arn = aws_efs_file_system.matrix_efs_configs.arn

  subdirectory = "/"

  ec2_config {
    security_group_arns = [aws_security_group.datasync_sg.arn]
    subnet_arn          = aws_subnet.private[0].arn
  }

  depends_on = [aws_efs_mount_target.matrix_efs_configs]
}

resource "aws_datasync_task" "s3_to_efs_task" {
  source_location_arn      = aws_datasync_location_s3.s3_location.arn
  destination_location_arn = aws_datasync_location_efs.efs_location.arn
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync_log_group.arn
  name                     = "s3-to-efs-task"

  options {
    verify_mode            = "POINT_IN_TIME_CONSISTENT"
    overwrite_mode         = "ALWAYS"
    preserve_deleted_files = "PRESERVE"
    log_level              = "TRANSFER"
    task_queueing          = "ENABLED"
  }
}
