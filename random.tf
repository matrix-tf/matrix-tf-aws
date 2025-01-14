# Suffix
resource "random_id" "suffix" {
  byte_length = 4
}

# DB users
resource "random_password" "profile_user_password" {
  for_each         = aws_secretsmanager_secret.profile_user_password
  length           = 16
  special          = true
  override_special = "~!@#$%^&*()-_=+[]{}<>?"
}

# Homeserver 
resource "random_password" "registration_shared_secret" {
  length  = 32
  special = false
}

resource "random_password" "macaroon_secret_key" {
  length  = 64
  special = false
}

resource "random_password" "form_secret" {
  length  = 32
  special = false
}

# Bridges
resource "random_password" "bridge_as_token" {
  for_each = {
    for name, svc in var.services :
    name => svc
    if svc.profile == "bridge"
  }

  length  = 32
  special = false
}

resource "random_password" "bridge_hs_token" {
  for_each = {
    for name, svc in var.services :
    name => svc
    if svc.profile == "bridge"
  }

  length  = 32
  special = false
}

# Double-puppet
resource "random_password" "doublepuppet_as_token" {
  length  = 32
  special = false
}

resource "random_password" "doublepuppet_hs_token" {
  length  = 32
  special = false
}

# Signal
resource "random_password" "signal_pickle_key" {
  length           = 64
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}<>?"
}
