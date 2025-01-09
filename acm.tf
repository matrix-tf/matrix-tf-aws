resource "aws_acm_certificate" "self_signed_cert" {
  private_key      = tls_private_key.rsa_2048_key.private_key_pem
  certificate_body = tls_self_signed_cert.self_signed_tls_cert.cert_pem
}
