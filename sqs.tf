resource "aws_sqs_queue" "ecs_manager_state_machine_dlq" {
  name                      = "ecs-manager-state-machine-dlq"
  message_retention_seconds = 1209600
}
