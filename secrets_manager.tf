# Profiles
resource "aws_secretsmanager_secret" "profile_user_password" {
  for_each = local.profiles

  name        = "${each.key}-user-password"
  description = "Password for the ${local.profile_capitalize[each.key]} postgres user"
}

resource "aws_secretsmanager_secret_version" "profile_user_password" {
  for_each = aws_secretsmanager_secret.profile_user_password

  secret_id     = aws_secretsmanager_secret.profile_user_password[each.key].id
  secret_string = random_password.profile_user_password[each.key].result
}

# Signal
resource "aws_secretsmanager_secret" "pickle_key_secret" {
  name        = "signal-pickle-key"
  description = "Pickle key for Signal bridge"
}

resource "aws_secretsmanager_secret_version" "pickle_key_secret_value" {
  secret_id     = aws_secretsmanager_secret.pickle_key_secret.id
  secret_string = random_password.signal_pickle_key.result
}
