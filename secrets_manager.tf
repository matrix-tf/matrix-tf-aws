## Profiles
resource "aws_secretsmanager_secret" "profile_user_password" {
  for_each = local.profiles

  name        = "${each.key}-user-password-${random_id.suffix.hex}"
  description = "The password for the ${local.profile_capitalize[each.key]} postgres user"
}

resource "aws_secretsmanager_secret_version" "profile_user_password" {
  for_each = aws_secretsmanager_secret.profile_user_password

  secret_id     = aws_secretsmanager_secret.profile_user_password[each.key].id
  secret_string = random_password.profile_user_password[each.key].result
}
