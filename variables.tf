variable "region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = can(regex("^(ap|us|eu|ca|sa)-", var.region))
    error_message = "Region must be a valid AWS region code."
  }
}

variable "environment" {
  description = "Deployment environment (development, staging, production)"
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "instance_type" {
  description = "EC2 instance type for web servers (t3.micro or t4g.micro for cost optimization)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t4g.micro", "t3.small", "t4g.small"], var.instance_type)
    error_message = "Instance type must be t3.micro, t4g.micro, t3.small, or t4g.small for development environment cost optimization."
  }
}

variable "create_certificate" {
  description = "Whether to create a new ACM certificate (true) or use existing certificate_arn (false)"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for ACM certificate (e.g., '*.example.com' for wildcard). Required if create_certificate is true."
  type        = string
  default     = "*.example.com"
}

variable "certificate_arn" {
  description = "ARN of existing ACM certificate for HTTPS listener. Required if create_certificate is false. Leave empty to create new certificate."
  type        = string
  default     = ""

  validation {
    condition     = var.certificate_arn == "" || can(regex("^arn:aws:acm:", var.certificate_arn))
    error_message = "Certificate ARN must be empty or a valid ACM certificate ARN starting with 'arn:aws:acm:'."
  }
}

variable "availability_zones" {
  description = "List of availability zones for multi-AZ deployment (must be in deployment region)"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones required for high availability."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources for cost tracking and resource management"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Application = "ec2-alb-nginx"
  }
}
