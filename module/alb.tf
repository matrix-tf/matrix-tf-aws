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
    for service_name, service_def in var.services : service_name => service_def
    if service_def.enabled
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

  certificate_arn = aws_acm_certificate.main_cert.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Page Not Found"
      status_code  = "404"
    }
  }

  depends_on = [aws_acm_certificate_validation.main_cert_validation]
}

resource "aws_lb_listener_rule" "well_known_client" {
  listener_arn = aws_lb_listener.application_listener.arn
  priority     = 1

  condition {
    http_request_method {
      values = ["GET"]
    }
  }

  condition {
    path_pattern {
      values = ["/.well-known/matrix/client"]
    }
  }

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = <<JSON
{
  "m.homeserver": {
    "base_url": "https://${var.server_name}"
  },
  "m.identity_server": {
    "base_url": "https://identity.example.com"
  }
}
JSON
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "well_known_server" {
  listener_arn = aws_lb_listener.application_listener.arn
  priority     = 2

  condition {
    http_request_method {
      values = ["GET"]
    }
  }

  condition {
    path_pattern {
      values = ["/.well-known/matrix/server"]
    }
  }

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = <<JSON
{
  "m.server": "${var.server_name}:443"
}
JSON
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "bridge_forwarding" {
  for_each = {
    for service_name, service_def in var.services : service_name => service_def
    if service_def.enabled && service_def.profile == "bridge"
  }

  listener_arn = aws_lb_listener.application_listener.arn
  priority     = index(keys(var.services), each.key) + 3

  condition {
    http_header {
      http_header_name = "Bridge"
      values           = [each.key]
    }
  }

  condition {
    path_pattern {
      values = ["/_matrix/provision/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_target_group[each.key].arn
  }
}

resource "aws_lb_listener_rule" "bridge_header_invalid_path" {
  listener_arn = aws_lb_listener.application_listener.arn
  priority = length([
    for service_name, service_def in var.services :
    service_name if service_def.enabled && service_def.profile == "bridge"
  ]) + 4

  condition {
    http_header {
      http_header_name = "Bridge"
      values           = ["*"]
    }
  }

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "matrix_forwarding" {
  listener_arn = aws_lb_listener.application_listener.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["/_matrix/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_target_group["synapse"].arn
  }
}
