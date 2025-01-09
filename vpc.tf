resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "matrix-vpc"
  }
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id
  ]

  tags = {
    Name = "s3-vpc-endpoint"
  }
}


resource "aws_vpc_endpoint" "datasync_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.datasync"
  vpc_endpoint_type = "Interface"

  subnet_ids = aws_subnet.private[*].id
  security_group_ids = [
    aws_security_group.datasync_sg.id
  ]

  tags = {
    Name = "datasync-vpc-endpoint"
  }
}
