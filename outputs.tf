# =============================================================================
# Outputs - Infrastructure resource identifiers and endpoints
# =============================================================================

# Application Load Balancer outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use this to access the application via HTTPS)"
  value       = module.alb.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "alb_zone_id" {
  description = "Route53 hosted zone ID of the ALB (for DNS record creation)"
  value       = module.alb.zone_id
}

# Target Group outputs
output "target_group_arn" {
  description = "ARN of the target group containing EC2 instances"
  value       = module.alb.target_groups["ec2_targets"].arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = module.alb.target_groups["ec2_targets"].name
}

# EC2 Instance outputs
output "ec2_instance_ids" {
  description = "List of EC2 instance IDs"
  value = [
    module.ec2_instance_az_a.id,
    module.ec2_instance_az_b.id
  ]
}

output "ec2_instance_private_ips" {
  description = "List of EC2 instance private IP addresses"
  value = [
    module.ec2_instance_az_a.private_ip,
    module.ec2_instance_az_b.private_ip
  ]
}

output "ec2_instance_availability_zones" {
  description = "List of EC2 instance availability zones"
  value = [
    module.ec2_instance_az_a.availability_zone,
    module.ec2_instance_az_b.availability_zone
  ]
}

# Security Group outputs
output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = module.alb_security_group.security_group_id
}

output "ec2_security_group_id" {
  description = "Security group ID for EC2 instances"
  value       = module.ec2_security_group.security_group_id
}

# IAM Role outputs
output "iam_role_arn_az_a" {
  description = "IAM role ARN for EC2 instance in AZ A"
  value       = module.ec2_instance_az_a.iam_role_arn
}

output "iam_role_arn_az_b" {
  description = "IAM role ARN for EC2 instance in AZ B"
  value       = module.ec2_instance_az_b.iam_role_arn
}

# Certificate output
output "certificate_arn" {
  description = "ACM certificate ARN used for HTTPS listener"
  value       = var.certificate_arn
  sensitive   = false
}

# VPC outputs
output "vpc_id" {
  description = "ID of the default VPC used for deployment"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "List of subnet IDs used for multi-AZ deployment"
  value       = data.aws_subnets.default.ids
}

# Deployment Information
output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    alb_endpoint       = "https://${module.alb.dns_name}"
    health_check_path  = "/health"
    instance_count     = 2
    availability_zones = var.availability_zones
    instance_type      = var.instance_type
    tls_policy         = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    deployment_region  = var.region
    environment        = var.environment
  }
}
