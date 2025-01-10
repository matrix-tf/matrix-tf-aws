resource "aws_acm_certificate" "main_cert" {
  domain_name       = var.server_name
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "main_cert_validation" {
  certificate_arn         = aws_acm_certificate.main_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
