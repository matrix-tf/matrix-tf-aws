output "matrix_stack_url" {
  description = "The base URL for the Matrix homeserver + bridges stack"
  value       = "https://${var.server_name}"
}

output "enabled_services" {
  description = "List of enabled services"
  value       = [for k, v in var.services : k if v.enabled]
}
