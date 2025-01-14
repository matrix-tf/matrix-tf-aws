resource "aws_db_instance" "matrix_db" {
  identifier                  = "matrix-db"
  allocated_storage           = 20
  storage_type                = "gp2"
  engine                      = "postgres"
  instance_class              = "db.t4g.micro"
  port                        = 5432
  username                    = "postgres"
  manage_master_user_password = true
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]
  db_subnet_group_name        = aws_db_subnet_group.main.id
  publicly_accessible         = false
  skip_final_snapshot         = true
  storage_encrypted           = true
}

resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = aws_subnet.private[*].id
}
