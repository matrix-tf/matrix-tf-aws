resource "tls_private_key" "rsa_2048_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed_tls_cert" {
  private_key_pem       = tls_private_key.rsa_2048_key.private_key_pem
  validity_period_hours = 8760
  is_ca_certificate     = true
  early_renewal_hours   = 1440
  subject {
    country = "US"
  }
  dns_names = ["*.elb.amazonaws.com"]

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}
