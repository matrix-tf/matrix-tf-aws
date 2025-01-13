variable "alb_permitted_ips" {
  description = "IPs permitted for inbound traffic"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "us-east-2"
}

variable "server_name" {
  description = "The server name for the application"
  type        = string
  default     = null
}

variable "aws_credentials" {
  description = "AWS credentials"
  type = object({
    access_key = string
    secret_key = string
  })
}

variable "telegram_app_registration" {
  description = "Telegram API registration"
  type = object({
    id   = string
    hash = string
  })
  default = null

  validation {
    condition = (
      var.services["telegram"].enabled == false || var.telegram_app_registration != null
    )
    error_message = <<EOT
If the Telegram service is enabled, telegram_app_registration must not be null.

telegram_app_registration = {
    id   = "api-id"
    hash = "api-hash"
}

See https://my.telegram.org/apps for more info.
EOT
  }
}

variable "services" {
  description = "Configuration of Services"
  type = map(object({
    enabled      = bool
    port         = number
    image        = string
    version      = string
    health_check = string
    profile      = string
  }))

  default = {
    synapse  = { enabled = true, port = 8008, image = "matrixdotorg/synapse", version = "v1.121.1", health_check = "/health", profile = "synapse" }
    discord  = { enabled = false, port = 29316, image = "dock.mau.dev/mautrix/discord", version = "v0.7.2", health_check = "/_matrix/mau/live", profile = "bridge" }
    signal   = { enabled = false, port = 29317, image = "dock.mau.dev/mautrix/signal", version = "v0.7.4", health_check = "/_matrix/mau/live", profile = "bridge" }
    telegram = { enabled = false, port = 29318, image = "dock.mau.dev/mautrix/telegram", version = "v0.15.2", health_check = "/_matrix/mau/live", profile = "bridge" }
    whatsapp = { enabled = false, port = 29319, image = "dock.mau.dev/mautrix/whatsapp", version = "v0.11.2", health_check = "/_matrix/mau/live", profile = "bridge" }
  }

  validation {
    condition     = var.services["synapse"].enabled == true
    error_message = "Synapse is currently the only supported homeserver and therefore must always be enabled."
  }

  validation {
    condition = alltrue([
      for _, service in var.services : service.port >= 1024 && service.port <= 65535
    ])
    error_message = "All ports must be valid non-system port numbers between 1024 and 65535."
  }

  validation {
    condition = alltrue([
      for _, service in var.services : contains(keys(local.profiles), service.profile)
    ])
    error_message = "Each service must have a profile that matches one of the valid profiles: ${join(", ", keys(local.profiles))}."
  }
}
