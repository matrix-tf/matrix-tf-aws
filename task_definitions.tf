resource "aws_ecs_task_definition" "service_task" {
  for_each = {
    for name, service in var.services : name => service
    if service.enabled
  }

  family                   = "${each.key}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.services_role.arn
  task_role_arn            = aws_iam_role.services_role.arn

  volume {
    name = "${each.key}-config"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.matrix_efs_configs.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.service_access_point[each.key].id
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "${each.key}-init"
      image     = "postgres:15"
      essential = false
      secrets = [
        {
          name      = "RDS_CREDS"
          valueFrom = aws_db_instance.matrix_db.master_user_secret[0].secret_arn
        },
        {
          name      = "PROFILE_USER_PASSWORD"
          valueFrom = aws_secretsmanager_secret_version.profile_user_password[each.value.profile].arn
        }
      ]
      environment = [
        { name = "POSTGRES_PASSWORD", value = "postgres" },
        { name = "POSTGRES_USER", value = "postgres" },
        { name = "PGHOST", value = aws_db_instance.matrix_db.address },
        { name = "PGSSLMODE", value = "require" },
      ]
      command = [
        "bash", "-c",
        <<EOC
          set -euo pipefail

          # Extract username and password from JSON
          PGUSER=$(echo "$RDS_CREDS" | grep -o '"username":"[^"]*' | cut -d'"' -f4)
          PGPASSWORD=$(echo "$RDS_CREDS" | grep -o '"password":"[^"]*' | cut -d'"' -f4)
          export PGUSER PGPASSWORD

          db_name=${each.key}
          user_name=${each.value.profile}
          user_password=$${PROFILE_USER_PASSWORD}

          # Check if user exists
          if ! psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$${user_name}'" | grep -q 1; then
            echo "Creating user $${user_name}..."
            psql -c "CREATE ROLE $${user_name} WITH LOGIN PASSWORD '$${user_password}' CREATEDB;"
          else
            echo "User $${user_name} already exists."
          fi

          # Check if database exists
          if ! psql -tAc "SELECT 1 FROM pg_database WHERE datname = '$${db_name}'" | grep -q 1; then
            echo "Creating database $${db_name} with owner $${user_name}..."
            psql -c "CREATE DATABASE $${db_name} WITH OWNER = $${user_name} ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C' TEMPLATE = template0;"
          else
            echo "Database $${db_name} already exists."
          fi

          # Grant privileges
          echo "Granting privileges on database $${db_name} to $${user_name}..."
          psql -c "GRANT ALL PRIVILEGES ON DATABASE $${db_name} TO $${user_name};"

          # Ensure correct ownership for EFS files
          echo "Setting ownership & permissions for /data..."
          chown -R ${local.profiles[each.value.profile].uid}:${local.profiles[each.value.profile].gid} /data
          chmod -R 0755 /data
          echo "Ownership & permissions for /data set."

        EOC
      ]
      mountPoints = [
        {
          sourceVolume  = "${each.key}-config"
          containerPath = "/data"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "${each.key}-init"
        }
      }
    },
    {
      name      = each.key
      image     = "${each.value.image}:${each.value.version}"
      essential = true
      portMappings = [{
        containerPort = each.value.port
        hostPort      = each.value.port
      }]
      mountPoints = [
        {
          sourceVolume  = "${each.key}-config"
          containerPath = "/data"
        }
      ]
      dependsOn = [
        {
          containerName = "${each.key}-init"
          condition     = "SUCCESS"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = each.key
        }
      }
    }
  ])
}
