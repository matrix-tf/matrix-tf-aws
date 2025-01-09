resource "aws_lb" "application_lb" {
  name               = "application-public-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.application_lb_sg.id]
  subnets            = aws_subnet.public[*].id

  access_logs {
    bucket  = aws_s3_bucket.alb_logs_bucket.id
    prefix  = "alb-logs"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.alb_logs_bucket_policy]
}

resource "aws_lb_target_group" "service_target_group" {
  for_each = {
    for name, service in var.services : name => service
    if service.enabled
  }

  name        = "${each.key}-target-group"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = each.value.health_check
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "application_listener" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  certificate_arn = aws_acm_certificate.self_signed_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_target_group["synapse"].arn
  }
}

resource "aws_lb_listener_rule" "service_listener_rule" {
  for_each = {
    for name, service in var.services : name => service
    if service.enabled
  }

  listener_arn = aws_lb_listener.application_listener.arn
  priority     = index(keys(var.services), each.key) + 1

  condition {
    http_header {
      http_header_name = "Service"
      values           = [each.key]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_target_group[each.key].arn
  }
}
