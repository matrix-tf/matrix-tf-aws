resource "aws_wafv2_web_acl_association" "web_acl_association" {
  resource_arn = aws_lb.application_lb.arn
  web_acl_arn  = aws_wafv2_web_acl.web_acl.arn
}

resource "aws_wafv2_web_acl" "web_acl" {
  name        = "application-waf"
  scope       = "REGIONAL"
  description = "WAF for the application ALB"

  default_action {
    allow {}
  }

  # rule {
  #   name     = "AllowSpecificIPs"
  #   priority = 0

  #   statement {
  #     ip_set_reference_statement {
  #       arn = aws_wafv2_ip_set.allowed_ips.arn
  #     }
  #   }

  #   visibility_config {
  #     cloudwatch_metrics_enabled = true
  #     sampled_requests_enabled   = true
  #     metric_name                = "allow-specific-ips"
  #   }

  #   action {
  #     allow {}
  #   }
  # }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            count {}
          }
          name = "SizeRestrictions_QUERYSTRING"
        }

        rule_action_override {
          action_to_use {
            count {}
          }
          name = "NoUserAgent_HEADER"
        }

      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "aws-managed-rules"
    }
  }

  rule {
    name     = "RateLimitRuleGroup"
    priority = 2

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.rate_limit_rules.arn
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "rate-limit-group"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "application-waf"
  }
}


# resource "aws_wafv2_ip_set" "allowed_ips" {
#   name        = "allowed-ips"
#   scope       = "REGIONAL"
#   description = "IP Set for allowing specific inbound traffic"

#   addresses = var.alb_permitted_ips

#   ip_address_version = "IPV4"
# }

resource "aws_wafv2_rule_group" "rate_limit_rules" {
  name        = "rate-limit-rule-group"
  scope       = "REGIONAL"
  capacity    = 20
  description = "Rate limiting rules"

  rule {
    name     = "RateLimitRequests"
    priority = 1

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "rate-limit"
    }

    action {
      block {}
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "rate-limit-group"
  }
}
