# =============================================================================
# Data Sources - Lookup existing AWS resources
# =============================================================================

# Default VPC lookup
data "aws_vpc" "default" {
  default = true
}

# Default subnets in the VPC across availability zones
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# =============================================================================
# ACM Certificate - SSL/TLS certificate for HTTPS
# =============================================================================

resource "aws_acm_certificate" "this" {
  count = var.create_certificate ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-acm-certificate"
    }
  )
}

# Output DNS validation records for manual DNS configuration
# Note: Automated DNS validation requires Route53 hosted zone
locals {
  certificate_arn = var.create_certificate ? aws_acm_certificate.this[0].arn : var.certificate_arn
}

# =============================================================================
# Security Groups - Defense-in-depth architecture
# =============================================================================

# ALB Security Group - Internet-facing, HTTPS only
module "alb_security_group" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "~> 5.3.1"

  name        = "${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer - HTTPS from internet"
  vpc_id      = data.aws_vpc.default.id

  # Allow HTTPS from internet
  ingress_rules       = ["https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  # Allow all outbound traffic (to reach EC2 instances)
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = local.common_tags
}

# EC2 Security Group - Only allow traffic from ALB
module "ec2_security_group" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "~> 5.3.1"

  name        = "${var.environment}-ec2-sg"
  description = "Security group for EC2 instances - HTTP from ALB only (defense-in-depth)"
  vpc_id      = data.aws_vpc.default.id

  # Allow HTTP from ALB security group only (not CIDR blocks)
  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "HTTP from ALB only"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]

  # Allow all outbound for package updates and external API calls
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = local.common_tags
}

# =============================================================================
# EC2 Instances - Multi-AZ deployment with Nginx
# =============================================================================

# EC2 Instance in Availability Zone A
module "ec2_instance_az_a" {
  source  = "app.terraform.io/hashi-demos-apj/ec2-instance/aws"
  version = "~> 6.1.4"

  name = "${var.environment}-web-instance-az-a"

  # Instance configuration
  instance_type = var.instance_type
  ami           = data.aws_ami.amazon_linux_2023.id

  # Network placement
  subnet_id                   = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids      = [module.ec2_security_group.security_group_id]
  associate_public_ip_address = true

  # User data for Nginx installation and configuration
  user_data_base64 = base64encode(local.user_data_script)

  # IAM instance profile for Systems Manager Session Manager access
  create_iam_instance_profile = true
  iam_role_policies = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Enable detailed CloudWatch monitoring
  monitoring = true

  # Encrypted EBS root volume
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(
    local.common_tags,
    {
      Name             = "${var.environment}-web-instance-az-a"
      AvailabilityZone = var.availability_zones[0]
    }
  )
}

# EC2 Instance in Availability Zone B
module "ec2_instance_az_b" {
  source  = "app.terraform.io/hashi-demos-apj/ec2-instance/aws"
  version = "~> 6.1.4"

  name = "${var.environment}-web-instance-az-b"

  # Instance configuration
  instance_type = var.instance_type
  ami           = data.aws_ami.amazon_linux_2023.id

  # Network placement
  subnet_id                   = element(data.aws_subnets.default.ids, 1)
  vpc_security_group_ids      = [module.ec2_security_group.security_group_id]
  associate_public_ip_address = true

  # User data for Nginx installation and configuration
  user_data_base64 = base64encode(local.user_data_script)

  # IAM instance profile for Systems Manager Session Manager access
  create_iam_instance_profile = true
  iam_role_policies = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Enable detailed CloudWatch monitoring
  monitoring = true

  # Encrypted EBS root volume
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(
    local.common_tags,
    {
      Name             = "${var.environment}-web-instance-az-b"
      AvailabilityZone = var.availability_zones[1]
    }
  )
}

# =============================================================================
# Application Load Balancer - HTTPS with TLS 1.2/1.3
# =============================================================================

module "alb" {
  source  = "app.terraform.io/hashi-demos-apj/alb/aws"
  version = "~> 10.1.0"

  name    = "${var.environment}-alb"
  vpc_id  = data.aws_vpc.default.id
  subnets = data.aws_subnets.default.ids

  # Internet-facing load balancer
  load_balancer_type = "application"
  internal           = false

  # Security configuration
  security_groups = [module.alb_security_group.security_group_id]

  # Security hardening
  enable_deletion_protection       = true
  enable_cross_zone_load_balancing = true
  enable_http2                     = true
  drop_invalid_header_fields       = true

  # HTTPS listener with TLS 1.2/1.3 only
  listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = local.certificate_arn
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06" # TLS 1.2/1.3 only

      forward = {
        target_group_key = "ec2_targets"
      }
    }

    # HTTP listener - redirect to HTTPS
    http_redirect = {
      port     = 80
      protocol = "HTTP"

      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  # Target group for EC2 instances
  target_groups = {
    ec2_targets = {
      name_prefix                   = "web-"
      protocol                      = "HTTP"
      port                          = 80
      target_type                   = "instance"
      deregistration_delay          = 30
      load_balancing_algorithm_type = "round_robin"
      create_attachment             = false # Disable module's built-in attachments

      # Health check configuration
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        matcher             = "200"
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
    }
  }

  tags = local.common_tags
}

# =============================================================================
# Target Group Attachments - Register EC2 instances with ALB target group
# =============================================================================

resource "aws_lb_target_group_attachment" "instance_az_a" {
  target_group_arn = module.alb.target_groups["ec2_targets"].arn
  target_id        = module.ec2_instance_az_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "instance_az_b" {
  target_group_arn = module.alb.target_groups["ec2_targets"].arn
  target_id        = module.ec2_instance_az_b.id
  port             = 80
}
