locals {
  profiles = {
    synapse = { uid : 991, gid : 991 }
    bridge  = { uid : 1337, gid : 1337 }
  }
}

locals {
  server_name       = var.server_name != null ? var.server_name : aws_lb.application_lb.dns_name
  server_name_regex = replace(local.server_name, ".", "\\.")
}

# Synapse files
locals {
  homeserver_yaml = templatefile("${path.module}/config_templates/synapse/homeserver.tftpl", {
    server_name                = local.server_name
    synapse_port               = var.services.synapse.port
    db_user                    = var.services.synapse.profile
    db_user_pw                 = aws_secretsmanager_secret_version.profile_user_password[var.services.synapse.profile].secret_string
    db_host                    = aws_db_instance.matrix_db.address
    db_name                    = var.services.synapse.profile
    registration_shared_secret = random_password.registration_shared_secret.result
    macaroon_secret_key        = random_password.macaroon_secret_key.result
    form_secret                = random_password.form_secret.result
  })

  doublepuppet_registration_yaml = templatefile("${path.module}/config_templates/synapse/doublepuppet-registration.tftpl", {
    server_name_regex     = local.server_name_regex
    doublepuppet_as_token = random_password.doublepuppet_as_token.result
    doublepuppet_hs_token = random_password.doublepuppet_hs_token.result
  })

  synapse_log_config = templatefile("${path.module}/config_templates/synapse/synapse.log.config", {})
}

# Bridge files
locals {
  bridge_config_outputs = {
    for service_name, service_def in var.services :
    service_name => templatefile("${path.module}/config_templates/${service_name}/config.tftpl", merge({
      server_name           = local.server_name
      synapse_port          = var.services.synapse.port
      bridge_port           = service_def.port
      db_user               = service_def.profile
      db_user_pw            = urlencode(aws_secretsmanager_secret_version.profile_user_password[service_def.profile].secret_string)
      db_host               = aws_db_instance.matrix_db.address
      db_name               = service_name
      ecs_namespace         = aws_service_discovery_private_dns_namespace.ecs_namespace.name
      as_token              = random_password.bridge_as_token[service_name].result
      hs_token              = random_password.bridge_hs_token[service_name].result
      doublepuppet_as_token = random_password.doublepuppet_as_token.result
      }, service_name == "telegram" ? {
      api_id   = var.telegram_app_registration.id
      api_hash = var.telegram_app_registration.hash
    } : {}))
    if service_def.enabled && service_def.profile == "bridge"
  }

  bridge_registration_outputs = {
    for service_name, service_def in var.services :
    service_name => templatefile("${path.module}/config_templates/${service_name}/registration.tftpl", {
      server_name_regex = local.server_name_regex
      ecs_namespace     = aws_service_discovery_private_dns_namespace.ecs_namespace.name
      bridge_port       = service_def.port
      as_token          = random_password.bridge_as_token[service_name].result
      hs_token          = random_password.bridge_hs_token[service_name].result
    })
    if service_def.profile == "bridge"
  }
}

# Configs bucket structure
locals {
  config_and_reg_files = merge(
    {
      "synapse/homeserver.yaml"                = local.homeserver_yaml
      "synapse/doublepuppet-registration.yaml" = local.doublepuppet_registration_yaml
      "synapse/synapse.log.config"             = local.synapse_log_config
    },
    {
      for s_name, rendered_config in local.bridge_config_outputs :
      "${s_name}/config.yaml" => rendered_config
    },
    {
      for s_name, rendered_reg in local.bridge_registration_outputs :
      "${s_name}/registration.yaml" => rendered_reg
    },
    {
      for s_name, rendered_reg in local.bridge_registration_outputs :
      "synapse/${s_name}-registration.yaml" => rendered_reg
    }
  )
}
