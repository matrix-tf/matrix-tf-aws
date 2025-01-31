resource "aws_route53domains_registered_domain" "registered_domain" {
  domain_name = var.server_name
}

data "aws_route53_zone" "registered_zone" {
  name         = "${var.server_name}."
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main_cert.domain_validation_options : dvo.domain_name => dvo
  }

  zone_id = data.aws_route53_zone.registered_zone.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

resource "aws_route53_record" "alb_alias" {
  zone_id = data.aws_route53_zone.registered_zone.zone_id
  name    = var.server_name
  type    = "A"

  alias {
    name                   = aws_lb.application_lb.dns_name
    zone_id                = aws_lb.application_lb.zone_id
    evaluate_target_health = true
  }
}
