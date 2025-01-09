resource "aws_efs_file_system" "matrix_efs_configs" {
  encrypted        = true
  creation_token   = "matrix-efs-configs"
  performance_mode = "generalPurpose"
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
    Name = "matrix-efs-configs"
  }
}

resource "aws_efs_mount_target" "matrix_efs_configs" {
  for_each = { for idx, subnet in aws_subnet.private : idx => subnet.id }

  file_system_id  = aws_efs_file_system.matrix_efs_configs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_access_point" "service_access_point" {
  for_each = {
    for name, service in var.services : name => service
    if service.enabled
  }

  file_system_id = aws_efs_file_system.matrix_efs_configs.id

  posix_user {
    uid = 0
    gid = 0
  }

  root_directory {
    path = "/${each.key}"
    creation_info {
      owner_uid   = local.profiles[each.value.profile].uid
      owner_gid   = local.profiles[each.value.profile].gid
      permissions = "0755"
    }
  }
}
