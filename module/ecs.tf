resource "aws_ecs_cluster" "main" {
  name = "matrix-ecs-cluster"
}

resource "aws_ecs_service" "service" {
  for_each = {
    for name, service in var.services : name => service
    if service.enabled
  }

  name                 = "${each.key}-service"
  cluster              = aws_ecs_cluster.main.id
  task_definition      = aws_ecs_task_definition.service_task[each.key].arn
  launch_type          = "FARGATE"
  desired_count        = 0
  force_new_deployment = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.services_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service_target_group[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.services[each.key].arn
  }

  tags = {
    ConfigsHash = ""
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      tags
    ]
  }
}

resource "null_resource" "ecs_services_ready" {
  triggers = {
    services = join(",", [for s in keys(aws_ecs_service.service) : aws_ecs_service.service[s].id])
  }
}
