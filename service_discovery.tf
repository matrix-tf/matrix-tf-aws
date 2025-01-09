resource "aws_service_discovery_private_dns_namespace" "ecs_namespace" {
  name        = "ecs.local"
  description = "Private DNS namespace for ECS services"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "services" {
  for_each = {
    for name, service in var.services : name => service
    if service.enabled
  }

  name         = each.key
  namespace_id = aws_service_discovery_private_dns_namespace.ecs_namespace.id
  description  = "${local.service_capitalize[each.key]} service"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.ecs_namespace.id
    dns_records {
      type = "A"
      ttl  = 60
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}
