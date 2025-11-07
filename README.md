# ai-iac-consumer-template
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.20.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb"></a> [alb](#module\_alb) | app.terraform.io/hashi-demos-apj/alb/aws | ~> 10.1.0 |
| <a name="module_alb_security_group"></a> [alb\_security\_group](#module\_alb\_security\_group) | app.terraform.io/hashi-demos-apj/security-group/aws | ~> 5.3.1 |
| <a name="module_ec2_instance_az_a"></a> [ec2\_instance\_az\_a](#module\_ec2\_instance\_az\_a) | app.terraform.io/hashi-demos-apj/ec2-instance/aws | ~> 6.1.4 |
| <a name="module_ec2_instance_az_b"></a> [ec2\_instance\_az\_b](#module\_ec2\_instance\_az\_b) | app.terraform.io/hashi-demos-apj/ec2-instance/aws | ~> 6.1.4 |
| <a name="module_ec2_security_group"></a> [ec2\_security\_group](#module\_ec2\_security\_group) | app.terraform.io/hashi-demos-apj/security-group/aws | ~> 5.3.1 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_lb_target_group_attachment.instance_az_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_lb_target_group_attachment.instance_az_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_ami.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones for multi-AZ deployment (must be in deployment region) | `list(string)` | <pre>[<br/>  "ap-southeast-2a",<br/>  "ap-southeast-2b"<br/>]</pre> | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ARN of existing ACM certificate for HTTPS listener. Required if create\_certificate is false. Leave empty to create new certificate. | `string` | `""` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tags to apply to all resources for cost tracking and resource management | `map(string)` | <pre>{<br/>  "Application": "ec2-alb-nginx",<br/>  "ManagedBy": "Terraform"<br/>}</pre> | no |
| <a name="input_create_certificate"></a> [create\_certificate](#input\_create\_certificate) | Whether to create a new ACM certificate (true) or use existing certificate\_arn (false) | `bool` | `true` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for ACM certificate (e.g., '*.example.com' for wildcard). Required if create\_certificate is true. | `string` | `"*.example.com"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (development, staging, production) | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for web servers (t3.micro or t4g.micro for cost optimization) | `string` | `"t3.micro"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for infrastructure deployment | `string` | `"ap-southeast-2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the Application Load Balancer |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer (use this to access the application via HTTPS) |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group ID for Application Load Balancer |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Route53 hosted zone ID of the ALB (for DNS record creation) |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ACM certificate ARN used for HTTPS listener |
| <a name="output_certificate_dns_validation_records"></a> [certificate\_dns\_validation\_records](#output\_certificate\_dns\_validation\_records) | DNS validation records for ACM certificate. Add these to your DNS provider to complete validation. |
| <a name="output_certificate_status"></a> [certificate\_status](#output\_certificate\_status) | Status of the ACM certificate (PENDING\_VALIDATION, ISSUED, etc.) |
| <a name="output_deployment_summary"></a> [deployment\_summary](#output\_deployment\_summary) | Summary of deployed infrastructure |
| <a name="output_ec2_instance_availability_zones"></a> [ec2\_instance\_availability\_zones](#output\_ec2\_instance\_availability\_zones) | List of EC2 instance availability zones |
| <a name="output_ec2_instance_ids"></a> [ec2\_instance\_ids](#output\_ec2\_instance\_ids) | List of EC2 instance IDs |
| <a name="output_ec2_instance_private_ips"></a> [ec2\_instance\_private\_ips](#output\_ec2\_instance\_private\_ips) | List of EC2 instance private IP addresses |
| <a name="output_ec2_security_group_id"></a> [ec2\_security\_group\_id](#output\_ec2\_security\_group\_id) | Security group ID for EC2 instances |
| <a name="output_iam_role_arn_az_a"></a> [iam\_role\_arn\_az\_a](#output\_iam\_role\_arn\_az\_a) | IAM role ARN for EC2 instance in AZ A |
| <a name="output_iam_role_arn_az_b"></a> [iam\_role\_arn\_az\_b](#output\_iam\_role\_arn\_az\_b) | IAM role ARN for EC2 instance in AZ B |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | List of subnet IDs used for multi-AZ deployment |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the target group containing EC2 instances |
| <a name="output_target_group_name"></a> [target\_group\_name](#output\_target\_group\_name) | Name of the target group |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the default VPC used for deployment |
<!-- END_TF_DOCS -->
