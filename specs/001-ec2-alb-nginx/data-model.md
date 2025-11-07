# Infrastructure Resource Model: EC2 with ALB and Nginx

**Feature**: EC2 Infrastructure with ALB and Nginx
**Date**: 2025-11-07
**Purpose**: Define AWS infrastructure resources, their relationships, and configuration requirements

---

## Resource Entities

### 1. VPC (Virtual Private Cloud)

**Type**: Data Source (existing default VPC)
**Source**: `data.aws_vpc.default`

**Attributes**:
- `id`: VPC identifier (string, UUID format)
- `cidr_block`: IP address range for VPC (string, CIDR notation)
- `default`: Boolean indicating if this is the default VPC (true)
- `enable_dns_hostnames`: DNS hostname support (boolean)
- `enable_dns_support`: DNS resolution support (boolean)

**Relationships**:
- **Contains**: Subnets
- **Associated with**: Security Groups, Route Tables, Internet Gateway

**Constraints**:
- Must be the default VPC in ap-southeast-2 region
- Must have at least 2 subnets in different availability zones

**Terraform Expression**:
```hcl
data "aws_vpc" "default" {
  default = true
}
```

---

### 2. Subnets

**Type**: Data Source (existing default subnets)
**Source**: `data.aws_subnets.default`

**Attributes**:
- `ids`: List of subnet identifiers (list of strings)
- `availability_zones`: List of AZs where subnets exist (list of strings)
- `cidr_blocks`: IP address ranges for each subnet (list of strings)
- `vpc_id`: Parent VPC identifier (string, foreign key to VPC)

**Relationships**:
- **Contained by**: VPC
- **Hosts**: EC2 Instances, ALB network interfaces

**Constraints**:
- Minimum 2 subnets required (multi-AZ deployment)
- Must span ap-southeast-2a and ap-southeast-2b availability zones
- Must have public internet routing (default VPC characteristic)

**Terraform Expression**:
```hcl
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
```

---

### 3. ALB Security Group

**Type**: Module Resource
**Module**: `app.terraform.io/hashi-demos-apj/security-group/aws` v5.3.1
**Identifier**: `module.alb_security_group`

**Attributes**:
- `id`: Security group identifier (string, sg-XXXXXXXX)
- `arn`: Amazon Resource Name (string)
- `name`: Human-readable name (string, e.g., "alb-security-group")
- `description`: Purpose description (string)
- `vpc_id`: Parent VPC identifier (string, foreign key)

**Ingress Rules**:
| Rule Name | Protocol | Port | Source | Purpose |
|-----------|----------|------|--------|---------|
| https-443-tcp | TCP | 443 | 0.0.0.0/0 | HTTPS from internet |
| http-80-tcp (optional) | TCP | 80 | 0.0.0.0/0 | HTTP redirect to HTTPS |

**Egress Rules**:
| Rule Name | Protocol | Port | Destination | Purpose |
|-----------|----------|------|-------------|---------|
| http-80-tcp | TCP | 80 | EC2 Security Group | Backend communication |

**Relationships**:
- **Associated with**: Application Load Balancer
- **Allows traffic to**: EC2 Security Group

**Constraints**:
- Must allow HTTPS (443) from internet (0.0.0.0/0)
- Must allow outbound to EC2 security group on port 80
- Must be associated with VPC

**Configuration**:
```hcl
module "alb_security_group" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "~> 5.3.1"

  name        = "${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  ingress_rules       = ["https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "HTTP to backend instances"
      source_security_group_id = module.ec2_security_group.security_group_id
    }
  ]
}
```

---

### 4. EC2 Security Group

**Type**: Module Resource
**Module**: `app.terraform.io/hashi-demos-apj/security-group/aws` v5.3.1
**Identifier**: `module.ec2_security_group`

**Attributes**:
- `id`: Security group identifier (string, sg-XXXXXXXX)
- `arn`: Amazon Resource Name (string)
- `name`: Human-readable name (string, e.g., "ec2-security-group")
- `vpc_id`: Parent VPC identifier (string, foreign key)

**Ingress Rules**:
| Rule Name | Protocol | Port | Source | Purpose |
|-----------|----------|------|--------|---------|
| http-80-tcp | TCP | 80 | ALB Security Group | Traffic from load balancer |

**Egress Rules**:
| Rule Name | Protocol | Port | Destination | Purpose |
|-----------|----------|------|-------------|---------|
| all-all | All | All | 0.0.0.0/0 | Outbound internet (updates, APIs) |

**Relationships**:
- **Associated with**: EC2 Instances
- **Receives traffic from**: ALB Security Group

**Constraints**:
- Must ONLY allow HTTP (80) from ALB security group (security group reference, not CIDR)
- Must NOT allow SSH from internet (0.0.0.0/0:22 prohibited)
- Must allow outbound for package updates and external API calls

**Security Rationale**: Defense-in-depth architecture prevents direct internet access to instances

**Configuration**:
```hcl
module "ec2_security_group" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "~> 5.3.1"

  name        = "${var.environment}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = data.aws_vpc.default.id

  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "HTTP from ALB only"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
```

---

### 5. IAM Role for EC2 Instances

**Type**: Implicit (created by ec2-instance module)
**Module**: `app.terraform.io/hashi-demos-apj/ec2-instance/aws` v6.1.4
**Identifier**: Created when `create_iam_instance_profile = true`

**Attributes**:
- `arn`: IAM role ARN (string)
- `name`: Role name (string)
- `assume_role_policy`: Trust policy allowing EC2 to assume role (JSON)

**Attached Policies**:
| Policy | Type | Purpose |
|--------|------|---------|
| AmazonSSMManagedInstanceCore | AWS Managed | Systems Manager Session Manager access |
| CloudWatch Logs Write | Custom Inline | Write application logs to CloudWatch |

**Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:ap-southeast-2:*:log-group:/aws/ec2/*"
    }
  ]
}
```

**Relationships**:
- **Assumed by**: EC2 Instances (via instance profile)
- **Grants access to**: Systems Manager, CloudWatch Logs

**Constraints**:
- Must follow least privilege principle
- Must NOT have AdministratorAccess or PowerUserAccess
- Must use instance profile (no long-lived credentials)

---

### 6. EC2 Instances

**Type**: Module Resource
**Module**: `app.terraform.io/hashi-demos-apj/ec2-instance/aws` v6.1.4
**Identifier**: `module.ec2_instance_az_a`, `module.ec2_instance_az_b`
**Count**: 2 (1 per availability zone)

**Attributes**:
- `id`: Instance identifier (string, i-XXXXXXXXXXXXXXXX)
- `arn`: Amazon Resource Name (string)
- `private_ip`: Private IP address (string, from VPC CIDR)
- `public_ip`: Public IP address (string, if assigned)
- `availability_zone`: Placement zone (string, ap-southeast-2a or ap-southeast-2b)
- `instance_type`: Instance size (string, e.g., "t3.micro")
- `ami`: Amazon Machine Image ID (string, Amazon Linux 2023)
- `instance_state`: Current state (string, e.g., "running")

**Configuration Attributes**:
- `user_data`: Bootstrap script (base64-encoded bash script)
- `iam_instance_profile`: Associated IAM role (string, ARN)
- `vpc_security_group_ids`: Attached security groups (list of strings)
- `subnet_id`: Placement subnet (string, foreign key)
- `monitoring`: Detailed CloudWatch monitoring (boolean, true)

**User Data Script**:
```bash
#!/bin/bash
# Update system packages
dnf update -y

# Install Nginx web server
dnf install -y nginx

# Start and enable Nginx service
systemctl start nginx
systemctl enable nginx

# Create health check endpoint
echo "OK" > /usr/share/nginx/html/health

# Optional: Custom welcome page
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Welcome</title></head>
<body>
  <h1>Web Server in $(ec2-metadata --availability-zone | cut -d ' ' -f 2)</h1>
  <p>Instance ID: $(ec2-metadata --instance-id | cut -d ' ' -f 2)</p>
</body>
</html>
EOF
```

**Relationships**:
- **Placed in**: Subnet (1 per AZ)
- **Protected by**: EC2 Security Group
- **Assumes**: IAM Role
- **Registered with**: ALB Target Group

**Constraints**:
- Instance type: t3.micro or t4g.micro (development cost optimization)
- AMI: Amazon Linux 2023 (latest via SSM parameter)
- EBS encryption: Enabled by default
- IMDSv2: Required (module default)
- Public IP: Optional (default VPC assigns by default)
- Monitoring: Detailed CloudWatch metrics enabled

**Configuration**:
```hcl
module "ec2_instance_az_a" {
  source  = "app.terraform.io/hashi-demos-apj/ec2-instance/aws"
  version = "~> 6.1.4"

  name = "${var.environment}-web-instance-az-a"

  instance_type = var.instance_type
  ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

  subnet_id                   = local.subnet_az_a_id
  availability_zone           = "ap-southeast-2a"
  vpc_security_group_ids      = [module.ec2_security_group.security_group_id]
  associate_public_ip_address = true

  user_data = base64encode(local.user_data_script)

  create_iam_instance_profile = true
  iam_role_policies = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  monitoring = true

  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = local.common_tags
}
```

---

### 7. Application Load Balancer

**Type**: Module Resource
**Module**: `app.terraform.io/hashi-demos-apj/alb/aws` v10.1.0
**Identifier**: `module.alb`

**Attributes**:
- `id`: Load balancer identifier (string, ALB ID)
- `arn`: Amazon Resource Name (string)
- `arn_suffix`: ARN suffix for CloudWatch metrics (string)
- `dns_name**: DNS name for ALB (string, e.g., "my-alb-123456789.ap-southeast-2.elb.amazonaws.com")
- `zone_id`: Route53 hosted zone ID (string, for DNS records)
- `load_balancer_type`: Type (string, "application")
- `internal`: Internet-facing or internal (boolean, false for internet-facing)
- `ip_address_type`: IPv4 or dualstack (string, "ipv4")

**Configuration Attributes**:
- `subnets`: Placement subnets (list of strings, multi-AZ)
- `security_groups`: Attached security groups (list of strings)
- `enable_deletion_protection`: Prevent accidental deletion (boolean, true)
- `enable_cross_zone_load_balancing`: Distribute across AZs (boolean, true)
- `enable_http2`: HTTP/2 support (boolean, true)
- `drop_invalid_header_fields`: Security hardening (boolean, true)

**Listeners**:
| Listener | Protocol | Port | SSL Policy | Default Action |
|----------|----------|------|------------|----------------|
| HTTPS | HTTPS | 443 | ELBSecurityPolicy-TLS13-1-2-2021-06 | Forward to target group |
| HTTP (optional) | HTTP | 80 | N/A | Redirect to HTTPS (301) |

**Relationships**:
- **Placed in**: Subnets (multi-AZ)
- **Protected by**: ALB Security Group
- **Routes traffic to**: Target Group
- **Uses certificate from**: ACM (AWS Certificate Manager)

**Constraints**:
- Must be internet-facing (not internal)
- Must span at least 2 availability zones
- Must use modern TLS policy (TLS 1.2/1.3 only)
- Must have deletion protection enabled
- Must have HTTP to HTTPS redirect configured

**Configuration**:
```hcl
module "alb" {
  source  = "app.terraform.io/hashi-demos-apj/alb/aws"
  version = "~> 10.1.0"

  name    = "${var.environment}-alb"
  vpc_id  = data.aws_vpc.default.id
  subnets = data.aws_subnets.default.ids

  load_balancer_type = "application"
  internal           = false

  security_group_ingress_rules = {
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS from internet"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = var.certificate_arn
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

      forward = {
        target_group_key = "ec2_targets"
      }
    }
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

  target_groups = {
    ec2_targets = {
      name_prefix = "web-"
      protocol    = "HTTP"
      port        = 80
      target_type = "instance"

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

      create_attachment = true
      target_id         = module.ec2_instance_az_a.id
    }
  }

  enable_deletion_protection         = true
  enable_cross_zone_load_balancing   = true
  enable_http2                       = true
  drop_invalid_header_fields         = true

  tags = local.common_tags
}
```

---

### 8. Target Group

**Type**: Managed by ALB Module
**Identifier**: Defined within `module.alb.target_groups`

**Attributes**:
- `arn`: Target group ARN (string)
- `arn_suffix`: ARN suffix for metrics (string)
- `name`: Target group name (string)
- `protocol`: Backend protocol (string, "HTTP")
- `port`: Backend port (number, 80)
- `target_type`: Type of targets (string, "instance")
- `vpc_id`: Parent VPC (string, foreign key)

**Health Check Configuration**:
| Parameter | Value | Purpose |
|-----------|-------|---------|
| enabled | true | Enable health checking |
| protocol | HTTP | Health check protocol |
| port | traffic-port | Use same port as traffic |
| path | `/health` | Health check endpoint |
| interval | 30 seconds | Time between checks |
| timeout | 5 seconds | Response timeout |
| healthy_threshold | 3 | Consecutive successes to mark healthy |
| unhealthy_threshold | 2 | Consecutive failures to mark unhealthy |
| matcher | "200" | Expected HTTP status code |

**Target Attachments**:
| Target | AZ | Health Status |
|--------|-----|---------------|
| EC2 Instance (AZ A) | ap-southeast-2a | Healthy |
| EC2 Instance (AZ B) | ap-southeast-2b | Healthy |

**Relationships**:
- **Associated with**: Application Load Balancer
- **Contains**: EC2 Instance targets (registered instances)
- **Performs health checks on**: EC2 Instances

**Constraints**:
- Health check path must exist on all targets (`/health`)
- Health check interval minimum 5 seconds, maximum 300 seconds
- Healthy threshold 2-10 consecutive successes
- Unhealthy threshold 2-10 consecutive failures
- Timeout must be less than interval

**Deregistration Delay**: 30 seconds (time for in-flight requests to complete)

---

### 9. SSL/TLS Certificate

**Type**: Variable Input (ACM Certificate ARN)
**Source**: AWS Certificate Manager (external to Terraform)
**Identifier**: `var.certificate_arn`

**Attributes**:
- `arn`: Certificate ARN (string, arn:aws:acm:ap-southeast-2:ACCOUNT:certificate/CERT-ID)
- `domain_name`: Primary domain name (string)
- `status`: Validation status (string, "ISSUED")
- `type`: Certificate type (string, "AMAZON_ISSUED" or "IMPORTED")

**Relationships**:
- **Used by**: Application Load Balancer HTTPS listener

**Constraints**:
- Must be in "ISSUED" status
- Must be in same region as ALB (ap-southeast-2)
- Must cover domain names used for ALB access
- Must be ACM-managed for automatic renewal

**Configuration**:
```hcl
variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS listener"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:", var.certificate_arn))
    error_message = "Certificate ARN must be a valid ACM certificate ARN"
  }
}
```

**Note**: Certificate creation outside Terraform scope. User must provide existing ACM certificate ARN or create via ACM console/CLI.

---

## Resource Relationships Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Region: ap-southeast-2              │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ VPC (Default VPC)                                         │   │
│  │                                                            │   │
│  │  ┌────────────────────┐        ┌────────────────────┐   │   │
│  │  │ Subnet (AZ A)      │        │ Subnet (AZ B)      │   │   │
│  │  │ ap-southeast-2a    │        │ ap-southeast-2b    │   │   │
│  │  │                    │        │                    │   │   │
│  │  │ ┌──────────────┐  │        │ ┌──────────────┐  │   │   │
│  │  │ │EC2 Instance  │  │        │ │EC2 Instance  │  │   │   │
│  │  │ │+ Nginx       │  │        │ │+ Nginx       │  │   │   │
│  │  │ │+ IAM Role    │  │        │ │+ IAM Role    │  │   │   │
│  │  │ └──────────────┘  │        │ └──────────────┘  │   │   │
│  │  └────────────────────┘        └────────────────────┘   │   │
│  │           │                             │                 │   │
│  │           │                             │                 │   │
│  │           └──────────────┬──────────────┘                 │   │
│  │                          │                                 │   │
│  │                          ▼                                 │   │
│  │                  ┌──────────────────┐                     │   │
│  │                  │  Target Group    │                     │   │
│  │                  │  + Health Checks │                     │   │
│  │                  └──────────────────┘                     │   │
│  │                          │                                 │   │
│  │                          ▼                                 │   │
│  │           ┌──────────────────────────────┐               │   │
│  │           │  Application Load Balancer    │               │   │
│  │           │  + HTTPS Listener (443)       │               │   │
│  │           │  + HTTP Redirect (80→443)     │               │   │
│  │           │  + SSL Certificate (ACM)      │               │   │
│  │           └──────────────────────────────┘               │   │
│  │                          │                                 │   │
│  └──────────────────────────┼─────────────────────────────────┘   │
│                             │                                     │
│                             ▼                                     │
│                      Internet Gateway                             │
│                             │                                     │
└─────────────────────────────┼─────────────────────────────────────┘
                              │
                              ▼
                        Public Internet
                      (HTTPS Traffic: 443)
```

---

## Resource Dependency Graph

```
┌──────────────────┐
│ VPC (Data Source)│
└────────┬─────────┘
         │
         ├──────────────────────────┐
         │                          │
         ▼                          ▼
┌─────────────────┐       ┌──────────────────┐
│Subnets (Data)   │       │Security Groups   │
└────────┬────────┘       │ - ALB SG         │
         │                │ - EC2 SG         │
         │                └─────┬────────────┘
         │                      │
         └──────────┬───────────┘
                    │
                    ├───────────────────────┐
                    │                       │
                    ▼                       ▼
            ┌──────────────┐       ┌──────────────────┐
            │EC2 Instances │       │ALB + Target Group│
            │ - AZ A       │       │ - Multi-AZ       │
            │ - AZ B       │       │ - HTTPS Listener │
            │ + IAM Role   │       │ + Certificate    │
            └──────┬───────┘       └─────────┬────────┘
                   │                         │
                   └──────────┬──────────────┘
                              │
                              ▼
                        Target Group
                        Attachments
```

---

## Configuration Variables Required

| Variable | Type | Purpose | Example Value |
|----------|------|---------|---------------|
| `environment` | string | Environment name | "development" |
| `region` | string | AWS region | "ap-southeast-2" |
| `instance_type` | string | EC2 instance size | "t3.micro" |
| `certificate_arn` | string | ACM certificate ARN | "arn:aws:acm:ap-southeast-2:..." |
| `common_tags` | map(string) | Resource tags | `{Environment = "dev", Project = "web"}` |

---

## Outputs Required

| Output | Type | Purpose | Consumer |
|--------|------|---------|----------|
| `alb_dns_name` | string | ALB DNS endpoint | Users, DNS configuration |
| `alb_arn` | string | ALB resource identifier | Monitoring, Route53 |
| `target_group_arn` | string | Target group identifier | Auto Scaling, monitoring |
| `ec2_instance_ids` | list(string) | Instance identifiers | Systems Manager, monitoring |
| `ec2_instance_private_ips` | list(string) | Private IP addresses | Troubleshooting, SSH (if needed) |
| `alb_security_group_id` | string | ALB security group ID | Network troubleshooting |
| `ec2_security_group_id` | string | EC2 security group ID | Network troubleshooting |
| `iam_role_arn` | string | IAM role ARN | Permissions validation |

---

## Summary

This infrastructure model defines 9 core entities with clearly defined relationships, constraints, and configurations. All resources follow module-first architecture using approved private registry modules, implement defense-in-depth security with layered security groups, and optimize for development environment cost constraints while maintaining production-ready security patterns.

**Key Relationships**:
1. VPC contains Subnets
2. Subnets host EC2 Instances and ALB network interfaces
3. Security Groups protect ALB and EC2 Instances with layered access control
4. IAM Role grants EC2 Instances AWS service access (no long-lived credentials)
5. EC2 Instances register with Target Group for health checking
6. ALB routes HTTPS traffic to healthy Target Group members
7. ACM Certificate enables HTTPS encryption at ALB

**Security Architecture**: Defense-in-depth with security group chaining (ALB SG → EC2 SG), IAM roles instead of credentials, ACM-managed certificates, TLS 1.2/1.3 only, and no SSH from internet.
