resource "aws_rds_cluster" "matrix_aurora" {
  cluster_identifier                    = "matrix-aurora-cluster"
  engine                                = "aurora-postgresql"
  engine_version                        = "16.6"
  engine_mode                           = "provisioned"
  database_name                         = "matrixdb"
  port                                  = 5432
  master_username                       = "postgres"
  manage_master_user_password           = true
  storage_encrypted                     = true
  backup_retention_period               = 7
  preferred_backup_window               = "07:00-09:00"
  skip_final_snapshot                   = true
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql"]
  db_subnet_group_name                  = aws_db_subnet_group.main.name
  vpc_security_group_ids                = [aws_security_group.aurora_sg.id]
  availability_zones = [
    sort(data.aws_availability_zones.available.names)[0],
    sort(data.aws_availability_zones.available.names)[1]
  ]

  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.0
  }

  lifecycle {
    ignore_changes = [
      availability_zones
    ]
  }
}

resource "aws_rds_cluster_instance" "matrix_aurora_instance" {
  identifier                            = "matrix-aurora-instance"
  cluster_identifier                    = aws_rds_cluster.matrix_aurora.id
  engine                                = aws_rds_cluster.matrix_aurora.engine
  engine_version                        = aws_rds_cluster.matrix_aurora.engine_version
  instance_class                        = "db.serverless"
  publicly_accessible                   = false
  apply_immediately                     = true
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
}

resource "aws_db_subnet_group" "main" {
  name        = "main"
  subnet_ids  = aws_subnet.private[*].id
  description = "Subnet group for Aurora Serverless"
}
