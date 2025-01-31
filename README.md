## Matrix-TF-AWS Module

This Terraform module deploys a [Matrix](https://matrix.org/) protocol Homeserver + Bridges stack to your AWS account. At a high-level, the following resources are created during deployment (full list below):

- VPC and associated networking resources
- ECS cluster containing homeserver and bridge services
- EFS and access points
- Aurora postgres cluster
- Two S3 buckets
- TLS certificate for your domain
- Dynamically-generated tokens/passwords which are stored in Secrets Manager
- and other resources to connect everything together

## Prior to Use

Before using this module, you will need the following:

1. A domain registered in Route 53 to use as your HS server_name
2. API ID and hash of a registered Telegram App (https://my.telegram.org/apps) (only if you plan to use the Telegram bridge)

That's it!

## Supported Services

The services listed below are the only ones that are currently supported.

**The service names cannot be modified as they correspond to included configuration files.**

## Example Usage

```
module "matrix-tf-aws" {
  source = "github.com/matrix-tf/matrix-tf-aws"

  # Required - AWS region where resources will be deployed
  aws_region = "us-east-2"

  # Optional - if not provided here (and it probably shouldn't be), AWS Provider priorities will be used for credentials
  aws_credentials = {
    access_key = "your-aws-account-access-key"
    secret_key = "your-aws-account-secret-key"
  }

  # Required - the domain you registered in Route 53 (usernames will look like this: @user:example.com)
  server_name = "example.com"

  # Optional - unless you intend to use the Telegram bridge
  telegram_app_registration = {
    id   = "your-telegram-app-id"
    hash = "your-telegram-app-hash"
  }

  # Optional - default value is provided below; include and adjust to customize
  services = {
    synapse  = { enabled = true, port = 8008, image = "matrixdotorg/synapse", version = "v1.123.0", health_check = "/health", profile = "synapse" }
    discord  = { enabled = false, port = 29316, image = "dock.mau.dev/mautrix/discord", version = "v0.7.2", health_check = "/_matrix/mau/live", profile = "bridge" }
    signal   = { enabled = false, port = 29317, image = "dock.mau.dev/mautrix/signal", version = "v0.7.5", health_check = "/_matrix/mau/live", profile = "bridge" }
    telegram = { enabled = false, port = 29318, image = "dock.mau.dev/mautrix/telegram", version = "v0.15.2", health_check = "/_matrix/mau/live", profile = "bridge" }
    whatsapp = { enabled = false, port = 29319, image = "dock.mau.dev/mautrix/whatsapp", version = "v0.11.2", health_check = "/_matrix/mau/live", profile = "bridge" }
  }

  # Optional - default value is provided here (permit all); adjust to restrict connections to your stack
  alb_permitted_ips = ["0.0.0.0/0"]
}
```

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                            | Version   |
| --------------------------------------------------------------- | --------- |
| <a name="requirement_aws"></a> [aws](#requirement_aws)          | ~> 5.84.0 |
| <a name="requirement_null"></a> [null](#requirement_null)       | ~> 3.2.3  |
| <a name="requirement_random"></a> [random](#requirement_random) | ~> 3.6.3  |

## Providers

| Name                                                      | Version |
| --------------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws)          | 5.84.0  |
| <a name="provider_null"></a> [null](#provider_null)       | 3.2.3   |
| <a name="provider_random"></a> [random](#provider_random) | 3.6.3   |

## Modules

No modules.

## Resources

| Name                                                                                                                                                                             | Type        |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_acm_certificate.main_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate)                                                     | resource    |
| [aws_acm_certificate_validation.main_cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation)                    | resource    |
| [aws_cloudwatch_event_rule.configs_bucket_event_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule)                         | resource    |
| [aws_cloudwatch_event_target.ecs_manager_state_machine_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target)              | resource    |
| [aws_cloudwatch_event_target.eventbridge_log_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target)                        | resource    |
| [aws_cloudwatch_log_group.ecs_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                                       | resource    |
| [aws_cloudwatch_log_group.eventbridge_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                               | resource    |
| [aws_cloudwatch_log_resource_policy.eventbridge_log_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_resource_policy)          | resource    |
| [aws_db_subnet_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group)                                                          | resource    |
| [aws_ecs_cluster.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster)                                                                  | resource    |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)                                                               | resource    |
| [aws_ecs_task_definition.service_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)                                          | resource    |
| [aws_efs_access_point.service_access_point](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point)                                        | resource    |
| [aws_efs_file_system.matrix_efs_configs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system)                                            | resource    |
| [aws_efs_mount_target.matrix_efs_configs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target)                                          | resource    |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip)                                                                                   | resource    |
| [aws_iam_role.ecs_manager_state_machine_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                              | resource    |
| [aws_iam_role.services_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                               | resource    |
| [aws_iam_role_policy.ecs_manager_state_machine_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                              | resource    |
| [aws_iam_role_policy.services_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                                               | resource    |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway)                                                        | resource    |
| [aws_lb.application_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)                                                                          | resource    |
| [aws_lb_listener.application_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)                                                  | resource    |
| [aws_lb_listener_rule.bridge_forwarding](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule)                                           | resource    |
| [aws_lb_listener_rule.bridge_header_invalid_path](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule)                                  | resource    |
| [aws_lb_listener_rule.matrix_forwarding](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule)                                           | resource    |
| [aws_lb_listener_rule.well_known_client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule)                                           | resource    |
| [aws_lb_listener_rule.well_known_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule)                                           | resource    |
| [aws_lb_target_group.service_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)                                          | resource    |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway)                                                                  | resource    |
| [aws_rds_cluster.matrix_aurora](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster)                                                         | resource    |
| [aws_rds_cluster_instance.matrix_aurora_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance)                              | resource    |
| [aws_route53_record.alb_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                                                       | resource    |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                                                 | resource    |
| [aws_route53domains_registered_domain.registered_domain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53domains_registered_domain)           | resource    |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)                                                               | resource    |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)                                                                | resource    |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association)                                       | resource    |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association)                                        | resource    |
| [aws_s3_bucket.alb_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)                                                           | resource    |
| [aws_s3_bucket.configs_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)                                                            | resource    |
| [aws_s3_bucket_notification.configs_bucket_to_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification)                   | resource    |
| [aws_s3_bucket_policy.alb_logs_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy)                                      | resource    |
| [aws_s3_bucket_policy.configs_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy)                                       | resource    |
| [aws_s3_bucket_public_access_block.alb_logs_bucket_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)             | resource    |
| [aws_s3_bucket_public_access_block.configs_bucket_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)              | resource    |
| [aws_s3_bucket_versioning.alb_logs_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning)                          | resource    |
| [aws_s3_bucket_versioning.configs_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning)                           | resource    |
| [aws_s3_object.config_and_reg_files](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object)                                                      | resource    |
| [aws_secretsmanager_secret.pickle_key_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                                 | resource    |
| [aws_secretsmanager_secret.profile_user_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                             | resource    |
| [aws_secretsmanager_secret_version.pickle_key_secret_value](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)           | resource    |
| [aws_secretsmanager_secret_version.profile_user_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)             | resource    |
| [aws_security_group.application_lb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                               | resource    |
| [aws_security_group.aurora_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                                       | resource    |
| [aws_security_group.efs_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                                          | resource    |
| [aws_security_group.services_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                                     | resource    |
| [aws_security_group_rule.alb_to_services_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule)                               | resource    |
| [aws_security_group_rule.services_sg_self_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule)                              | resource    |
| [aws_service_discovery_private_dns_namespace.ecs_namespace](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource    |
| [aws_service_discovery_service.services](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service)                                  | resource    |
| [aws_sfn_state_machine.ecs_manager_state_machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine)                                 | resource    |
| [aws_sqs_queue.ecs_manager_state_machine_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue)                                             | resource    |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)                                                                         | resource    |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)                                                                          | resource    |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)                                                                                  | resource    |
| [aws_vpc_endpoint.s3_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint)                                                         | resource    |
| [aws_wafv2_rule_group.rate_limit_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_rule_group)                                            | resource    |
| [aws_wafv2_web_acl.web_acl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl)                                                           | resource    |
| [aws_wafv2_web_acl_association.web_acl_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association)                       | resource    |
| [null_resource.ecs_services_ready](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)                                                        | resource    |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id)                                                                            | resource    |
| [random_password.bridge_as_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                                       | resource    |
| [random_password.bridge_hs_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                                       | resource    |
| [random_password.bridge_prov_shared_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                             | resource    |
| [random_password.doublepuppet_as_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                                 | resource    |
| [random_password.doublepuppet_hs_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                                 | resource    |
| [random_password.form_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                                           | resource    |
| [random_password.macaroon_secret_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                                   | resource    |
| [random_password.profile_user_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                                 | resource    |
| [random_password.registration_shared_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                            | resource    |
| [random_password.signal_pickle_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                                     | resource    |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones)                                            | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                                    | data source |
| [aws_route53_zone.registered_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone)                                                  | data source |

## Inputs

| Name                                                                                                         | Description                                             | Type                                                                                                                                                               | Default                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Required |
| ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------: |
| <a name="input_alb_permitted_ips"></a> [alb_permitted_ips](#input_alb_permitted_ips)                         | IPs permitted for inbound traffic                       | `list(string)`                                                                                                                                                     | <pre>[<br/> "0.0.0.0/0"<br/>]</pre>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |    no    |
| <a name="input_aws_credentials"></a> [aws_credentials](#input_aws_credentials)                               | AWS credentials                                         | <pre>object({<br/> access_key = string<br/> secret_key = string<br/> })</pre>                                                                                      | <pre>{<br/> "access_key": null,<br/> "secret_key": null<br/>}</pre>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |    no    |
| <a name="input_aws_region"></a> [aws_region](#input_aws_region)                                              | AWS region where resources will be deployed             | `string`                                                                                                                                                           | n/a                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |   yes    |
| <a name="input_server_name"></a> [server_name](#input_server_name)                                           | The server_name for the homeserver (i.e. 'example.com') | `string`                                                                                                                                                           | n/a                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |   yes    |
| <a name="input_services"></a> [services](#input_services)                                                    | Configuration of Services                               | <pre>map(object({<br/> enabled = bool<br/> port = number<br/> image = string<br/> version = string<br/> health_check = string<br/> profile = string<br/> }))</pre> | <pre>{<br/> "discord": {<br/> "enabled": false,<br/> "health_check": "/\_matrix/mau/live",<br/> "image": "dock.mau.dev/mautrix/discord",<br/> "port": 29316,<br/> "profile": "bridge",<br/> "version": "v0.7.2"<br/> },<br/> "signal": {<br/> "enabled": false,<br/> "health_check": "/\_matrix/mau/live",<br/> "image": "dock.mau.dev/mautrix/signal",<br/> "port": 29317,<br/> "profile": "bridge",<br/> "version": "v0.7.5"<br/> },<br/> "synapse": {<br/> "enabled": true,<br/> "health_check": "/health",<br/> "image": "matrixdotorg/synapse",<br/> "port": 8008,<br/> "profile": "synapse",<br/> "version": "v1.123.0"<br/> },<br/> "telegram": {<br/> "enabled": false,<br/> "health_check": "/\_matrix/mau/live",<br/> "image": "dock.mau.dev/mautrix/telegram",<br/> "port": 29318,<br/> "profile": "bridge",<br/> "version": "v0.15.2"<br/> },<br/> "whatsapp": {<br/> "enabled": false,<br/> "health_check": "/\_matrix/mau/live",<br/> "image": "dock.mau.dev/mautrix/whatsapp",<br/> "port": 29319,<br/> "profile": "bridge",<br/> "version": "v0.11.2"<br/> }<br/>}</pre> |    no    |
| <a name="input_telegram_app_registration"></a> [telegram_app_registration](#input_telegram_app_registration) | Telegram API registration                               | <pre>object({<br/> id = string<br/> hash = string<br/> })</pre>                                                                                                    | `null`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |    no    |

## Outputs

| Name                                                                                | Description                                            |
| ----------------------------------------------------------------------------------- | ------------------------------------------------------ |
| <a name="output_enabled_services"></a> [enabled_services](#output_enabled_services) | List of enabled services                               |
| <a name="output_matrix_stack_url"></a> [matrix_stack_url](#output_matrix_stack_url) | The base URL for the Matrix homeserver + bridges stack |

<!-- END_TF_DOCS -->

## License

This Terraform module is licensed under the [Apache 2.0 License](LICENSE).
