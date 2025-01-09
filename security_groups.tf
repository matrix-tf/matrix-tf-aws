## ALB SG
resource "aws_security_group" "application_lb_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "application-lb-sg"
  description = "ALB Security Group"

  tags = {
    Name = "application-lb-sg"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_permitted_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## Services SG
resource "aws_security_group" "services_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "services-sg"
  description = "ECS Services Security Group"

  tags = {
    Name = "services-sg"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "services_sg_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.services_sg.id
  source_security_group_id = aws_security_group.services_sg.id
}

resource "aws_security_group_rule" "alb_to_services_ingress" {
  for_each = {
    for name, service in var.services : name => service.port
    if service.enabled
  }

  type                     = "ingress"
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  security_group_id        = aws_security_group.services_sg.id
  source_security_group_id = aws_security_group.application_lb_sg.id
}

## RDS SG
resource "aws_security_group" "rds_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "rds-sg"
  description = "RDS Security Group"

  tags = {
    Name = "rds-sg"
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.services_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## EFS SG
resource "aws_security_group" "efs_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "efs-sg"
  description = "EFS Security Group"

  tags = {
    Name = "efs-sg"
  }

  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"
    security_groups = [
      aws_security_group.services_sg.id,
      aws_security_group.datasync_sg.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## DataSync SG
resource "aws_security_group" "datasync_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "datasync-sg"
  description = "DataSync Security Group"

  tags = {
    Name = "datasync-sg"
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      aws_vpc.main.cidr_block,
      "169.254.0.0/16" # AWS services (via VPC endpoints)
    ]
  }
}
