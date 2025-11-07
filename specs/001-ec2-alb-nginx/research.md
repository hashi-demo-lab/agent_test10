# Research: EC2 Infrastructure with ALB and Nginx

**Feature**: EC2 instances with Application Load Balancer and HTTPS
**Date**: 2025-11-07
**Organization**: hashi-demos-apj
**Region**: ap-southeast-2

---

## Module Selection Decisions

### 1. Application Load Balancer Module

**Decision**: Use `app.terraform.io/hashi-demos-apj/alb/aws` version `10.1.0`

**Rationale**:
- Only ALB module available in private registry
- Comprehensive HTTPS/SSL termination support including:
  - Certificate ARN specification
  - Multiple certificates per listener (SNI)
  - Configurable SSL policies
  - Mutual TLS authentication support
- Robust target group management with instance, IP, and lambda target types
- Advanced health check configuration with customizable intervals, timeouts, and HTTP status matching
- Built-in security group creation and management
- Production-ready features: access logging, connection logs, cross-zone load balancing, HTTP/2 support

**Key Capabilities**:
- HTTPS listener with TLS 1.2/1.3 support
- Target group health checks with configurable thresholds
- Security group ingress/egress rule management
- Route53 DNS record integration
- WAF integration support
- Deletion protection enabled by default

**Alternatives Considered**: None (only available ALB module in private registry)

**Module Source**: `app.terraform.io/hashi-demos-apj/alb/aws`
**Version**: `10.1.0`
**Provider Requirements**: AWS >= 6.19

---

### 2. EC2 Instance Module

**Decision**: Use `app.terraform.io/hashi-demos-apj/ec2-instance/aws` version `6.1.4`

**Rationale**:
- Only EC2 module available in private registry
- Full support for multi-AZ deployment via availability_zone parameter
- User data support for Nginx installation and configuration (user_data and user_data_base64)
- IAM instance profile support with create_iam_instance_profile flag
- Built-in security group creation with customizable ingress/egress rules
- IMDSv2 enforced by default for enhanced security
- Encrypted EBS volume support
- Cost optimization: supports spot instances for development

**Key Capabilities**:
- User data for bootstrapping Nginx web server
- IAM role integration for AWS service access
- Security group management
- CloudWatch monitoring integration
- Public/private subnet placement
- AMI selection via SSM parameters (always latest patches)

**Alternatives Considered**: None (only available EC2 module in private registry)

**Module Source**: `app.terraform.io/hashi-demos-apj/ec2-instance/aws`
**Version**: `6.1.4`
**Provider Requirements**: AWS >= 6.0

---

### 3. Security Group Module

**Decision**: Use `app.terraform.io/hashi-demos-apj/security-group/aws` version `5.3.1`

**Rationale**:
- Only security group module available in private registry
- Pre-defined named rules for common services (http-80-tcp, https-443-tcp)
- Supports custom rules with CIDR blocks
- Supports rules with source security group IDs (critical for ALB → EC2 traffic)
- Self-referencing rules for instance-to-instance communication
- Flexible rule definition methods for various security patterns

**Key Capabilities**:
- Named rules: `http-80-tcp`, `https-443-tcp` for web traffic
- Source security group references for defense-in-depth architecture
- IPv4 and IPv6 CIDR block support
- Computed values support for dynamic scenarios
- Tag-based management

**Alternatives Considered**: None (only available security group module in private registry)

**Module Source**: `app.terraform.io/hashi-demos-apj/security-group/aws`
**Version**: `5.3.1`
**Provider Requirements**: AWS >= 3.29

---

## SSL/TLS Certificate Management

### Decision: Use AWS Certificate Manager (ACM)

**Rationale**:
- Automatic certificate renewal (renews 60 days before expiration)
- Seamless ALB integration
- No manual certificate distribution or private key exposure
- CloudTrail logging for certificate lifecycle audit trail
- Free for use with AWS services (no additional cost)

**Implementation Approach**:
- Request certificate via ACM with DNS validation
- Use Route53 for automatic DNS validation record creation
- Associate certificate with ALB HTTPS listener
- Set SSL policy to `ELBSecurityPolicy-TLS13-1-2-2021-06` (TLS 1.2/1.3 only)

**Alternative Rejected**: Imported third-party certificates (no automatic renewal, higher operational overhead)

**Source**: [AWS Well-Architected Framework - SEC09-BP01: Implement secure key and certificate management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_key_cert_mgmt.html)

---

## Security Architecture

### Defense-in-Depth Security Group Design

**Decision**: Implement layered security groups with least privilege access

**Architecture**:
1. **ALB Security Group**: Internet-facing, allows HTTPS (443) from 0.0.0.0/0
2. **EC2 Security Group**: Internal, allows HTTP (80) ONLY from ALB security group (security group reference)
3. **No SSH from Internet**: Use AWS Systems Manager Session Manager for instance access

**Rationale**:
- Prevents direct internet access to EC2 instances
- Implements security group chaining (ALB → EC2)
- Eliminates SSH attack surface from internet
- Aligns with AWS Well-Architected Framework SEC05-BP02 (Control traffic flow)
- Reduces blast radius during security incidents

**Implementation**:
- ALB SG: Ingress 443 from 0.0.0.0/0, Egress to EC2 SG on port 80
- EC2 SG: Ingress 80 from ALB SG only, Egress to 0.0.0.0/0 for updates
- No ingress from 0.0.0.0/0:22 (SSH)

**Source**: [AWS Well-Architected Framework - SEC05-BP02: Control traffic flow within your network layers](https://docs.aws.amazon.com/wellarchitected/2025-02-25/framework/sec_network_protection_layered.html)

---

## IAM Role Design

### Decision: Least-privilege IAM roles with SSM permissions

**Rationale**:
- Eliminates need for long-lived credentials on instances
- Provides granular permissions scoped to specific resources
- Enables secure instance management via Systems Manager Session Manager
- Follows AWS principle of least privilege (SEC03-BP02)

**Required Permissions**:
1. **Systems Manager**: `AmazonSSMManagedInstanceCore` managed policy for Session Manager access
2. **CloudWatch Logs**: Write application and system logs
3. **Secrets Manager** (if needed): Read database credentials
4. **S3** (if needed): Read application configuration

**Implementation**:
- Create IAM role with EC2 assume role policy
- Attach least-privilege policies for specific use cases
- Use instance profile to associate role with EC2 instances
- No AWS access keys or secret keys in user data or configuration files

**Source**: [AWS Well-Architected Framework - SEC03-BP02: Grant least privilege access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_least_privileges.html)

---

## Network Architecture

### Decision: Use existing default VPC for development environment

**Rationale**:
- Requirement specifies using existing default VPC
- Acceptable for development/sandbox environment
- Production deployment would require custom VPC with private subnets

**Architecture**:
- **ALB**: Deploy in default public subnets across 2 availability zones
- **EC2 Instances**: Deploy in default public subnets (1 instance per AZ for development)
- **Internet Connectivity**: Direct via Internet Gateway (default VPC configuration)

**Multi-AZ Strategy**:
- Use `ap-southeast-2a` and `ap-southeast-2b` availability zones
- Deploy 1 EC2 instance per AZ (total 2 instances for cost optimization)
- ALB automatically distributes across both AZs
- Target group registers instances from both AZs

**Production Recommendation**:
- Use custom VPC with private subnets for EC2 instances
- Place ALB in public subnets, EC2 in private subnets
- Use NAT Gateway for outbound internet access from private subnets
- Enable VPC Flow Logs for network monitoring

**Source**: [VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)

---

## HTTPS/TLS Configuration

### Decision: Modern TLS policy with TLS 1.2 and 1.3 only

**SSL Policy**: `ELBSecurityPolicy-TLS13-1-2-2021-06`

**Rationale**:
- Supports TLS 1.3 and TLS 1.2 only (excludes vulnerable TLS 1.0/1.1)
- Provides Perfect Forward Secrecy (PFS) for all cipher suites
- Aligns with PCI-DSS compliance requirements (TLS 1.2+ mandatory)
- Industry best practice for modern web applications

**Cipher Suites Supported**:
- TLS 1.3: TLS_AES_128_GCM_SHA256, TLS_AES_256_GCM_SHA384, TLS_CHACHA20_POLY1305_SHA256
- TLS 1.2: ECDHE-ECDSA-AES128-GCM-SHA256, ECDHE-RSA-AES128-GCM-SHA256, ECDHE-ECDSA-AES256-GCM-SHA384, ECDHE-RSA-AES256-GCM-SHA384

**HTTP to HTTPS Redirect**:
- Configure HTTP listener on port 80
- Redirect all HTTP traffic to HTTPS with 301 permanent redirect
- Ensures all traffic is encrypted in transit

**Source**: [AWS Well-Architected Framework - SEC09-BP02: Enforce encryption in transit](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_encrypt.html)
**Reference**: [ALB Security Policies](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/describe-ssl-policies.html)

---

## Nginx Installation and Configuration

### Decision: Install Nginx via EC2 user data with Amazon Linux 2023

**Rationale**:
- Nginx available in standard Amazon Linux 2023 repositories
- User data provides automated, repeatable installation
- No manual configuration required
- Idempotent setup script

**Installation Script**:
```bash
#!/bin/bash
# Update system packages
dnf update -y

# Install Nginx
dnf install -y nginx

# Start and enable Nginx service
systemctl start nginx
systemctl enable nginx

# Create simple health check page
echo "OK" > /usr/share/nginx/html/health

# Configure Nginx to listen on port 80 (default)
# Serve static content from /usr/share/nginx/html
```

**Health Check Configuration**:
- ALB health check endpoint: `/health`
- Target port: 80 (HTTP)
- Health check interval: 30 seconds
- Healthy threshold: 3 consecutive successes
- Unhealthy threshold: 2 consecutive failures
- Timeout: 5 seconds
- Expected status: HTTP 200

**Alternatives Considered**:
- **AMI with pre-installed Nginx**: More complex, requires custom AMI management
- **Configuration management tools** (Ansible, Chef): Over-engineering for simple dev environment

---

## Cost Optimization for Development Environment

### Strategy 1: Use Smallest Viable Instance Types

**Decision**: Use `t3.micro` instances for development

**Rationale**:
- Burstable performance instances suitable for variable development workloads
- 2 vCPUs, 1 GB memory sufficient for Nginx web server
- Lowest cost option for development
- ap-southeast-2 pricing: $0.0132/hour × 730 hours = $9.64/month per instance

**Estimated Monthly Cost** (2 instances):
- 2 × t3.micro instances: $19.28/month
- 1 × ALB: ~$22.00/month (base charge) + data transfer
- **Total**: ~$45/month (well under $100 budget)

**Alternative**: t4g.micro (Graviton/ARM) at $0.0106/hour (20% cheaper)

---

### Strategy 2: Graviton-based Instances (Cost Optimization)

**Recommendation**: Consider `t4g.micro` (ARM-based Graviton2) for additional 20% savings

**Rationale**:
- Graviton2 instances provide 20% cost savings vs. x86 equivalents
- Fully compatible with Nginx and standard web workloads
- Amazon Linux 2023 has native ARM64 support
- ap-southeast-2 pricing: $0.0106/hour × 730 hours = $7.74/month per instance

**Cost Comparison**:
- 2 × t3.micro (x86): $19.28/month
- 2 × t4g.micro (ARM): $15.48/month
- **Savings**: $3.80/month (20% reduction)

**Implementation Note**: Requires ARM64 AMI selection

**Source**: [AWS Graviton Processor](https://aws.amazon.com/ec2/graviton/)

---

### Strategy 3: Instance Scheduling for Development (Not Recommended for Initial Implementation)

**Consideration**: EC2 Instance Scheduler for non-business hours shutdown

**Potential Savings**: 70% cost reduction if instances run only during business hours (weekdays 8 AM - 6 PM)

**Why Not Recommended for This Use Case**:
- Adds complexity for minimal cost savings (instances already very cheap)
- Development environment may need 24/7 availability for testing
- Can be implemented later if budget constraints arise

**Source**: [EC2 Cost and Capacity Optimization](https://aws.amazon.com/ec2/cost-and-capacity/)

---

## Target Group and Health Check Design

### Decision: HTTP-based health checks with custom endpoint

**Configuration**:
- **Target Type**: instance
- **Protocol**: HTTP
- **Port**: 80
- **Health Check Path**: `/health`
- **Health Check Interval**: 30 seconds
- **Healthy Threshold**: 3 consecutive successes
- **Unhealthy Threshold**: 2 consecutive failures
- **Timeout**: 5 seconds
- **Success Codes**: 200

**Rationale**:
- Simple HTTP health check suitable for Nginx static content
- Custom `/health` endpoint provides explicit health status
- 30-second interval balances responsiveness with overhead
- Conservative thresholds (3 healthy, 2 unhealthy) prevent flapping during transient issues
- Automatic traffic routing away from unhealthy instances within 1 minute

**Deregistration Delay**: 30 seconds (time to complete in-flight requests before draining)

**Source**: [ALB Target Health Checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)

---

## HCP Terraform Deployment Configuration

### Decision: Deploy via HCP Terraform Cloud with VCS-driven workflow

**Organization**: `hashi-demos-apj`
**Project**: `sandbox`
**Workspace**: `sandbox_ec2-alb-nginx` (to be created for testing)

**Rationale**:
- Centralized state management in HCP Terraform
- VCS-driven workflow for infrastructure as code
- Built-in policy enforcement via Sentinel
- Cost estimation for infrastructure changes
- Audit trail for all infrastructure modifications

**Deployment Workflow**:
1. Commit Terraform code to feature branch
2. Push to GitHub remote repository
3. HCP Terraform triggers automatic plan via VCS integration
4. Review plan output in HCP Terraform UI
5. Manual approval for apply operation
6. HCP Terraform executes apply and updates state

**Backend Configuration** (override.tf for testing):
```hcl
terraform {
  cloud {
    organization = "hashi-demos-apj"
    workspaces {
      name    = "sandbox_ec2-alb-nginx"
      project = "sandbox"
    }
  }
}
```

---

## Key Technical Constraints

### Region-Specific Constraints

**AWS Region**: ap-southeast-2 (Sydney, Australia)

**Available Availability Zones**:
- ap-southeast-2a
- ap-southeast-2b
- ap-southeast-2c

**Deployment Strategy**: Use ap-southeast-2a and ap-southeast-2b for 2-AZ deployment

---

### Default VPC Constraints

**Given**: Must use existing default VPC

**Implications**:
- Public subnets by default (map_public_ip_on_launch = true in default VPC)
- Default security group allows all outbound, denies all inbound
- Default network ACLs allow all traffic
- Internet Gateway already attached
- One default subnet per availability zone

**Security Considerations**:
- Override public IP assignment where possible
- Implement strict security group rules
- Consider VPC Flow Logs for monitoring (optional enhancement)

---

## Open Questions and Assumptions

### Assumptions Made

1. **SSL/TLS Certificate**: Assuming certificate will be created via ACM or provided by user as variable
2. **DNS Name**: Assuming ALB DNS name is acceptable (no custom domain requirement specified)
3. **Instance Count**: Deploying 2 instances (1 per AZ) for minimal cost with high availability
4. **Nginx Content**: Serving default Nginx welcome page (no custom application content specified)
5. **Monitoring**: Basic CloudWatch metrics enabled by default (no custom dashboards)
6. **Backup/DR**: No backup requirements for development environment
7. **Auto Scaling**: Not implementing Auto Scaling for cost-optimized development (static 2 instances)

### Questions for Clarification (if needed in future)

1. **Certificate Source**: Should we create ACM certificate or use existing certificate ARN?
2. **Custom Domain**: Do you want to associate a custom domain name with the ALB?
3. **Nginx Content**: Should we serve custom application content or default Nginx page?
4. **Monitoring Requirements**: Do you need custom CloudWatch dashboards or alerts?
5. **Auto Scaling**: Should we implement Auto Scaling for production readiness?

---

## Implementation Priorities

### Phase 1: Core Infrastructure (P1)
1. VPC data source lookup (default VPC)
2. Security groups (ALB and EC2)
3. IAM role for EC2 instances
4. EC2 instances with Nginx user data
5. ALB target group
6. Application Load Balancer with HTTPS listener

### Phase 2: Security Hardening (P1)
1. ACM certificate creation (if needed)
2. TLS 1.2/1.3 policy configuration
3. HTTP to HTTPS redirect
4. Security group rule validation

### Phase 3: Operational Excellence (P2)
1. CloudWatch monitoring
2. Health check validation
3. Testing and validation

### Phase 4: Cost Optimization (P3)
1. Graviton instance evaluation
2. Instance scheduling consideration
3. Resource tagging for cost tracking

---

## References

### AWS Documentation
- [ELB Infrastructure Security](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/infrastructure-security.html)
- [VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [IAM Roles for Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
- [ACM Services Integration](https://docs.aws.amazon.com/acm/latest/userguide/acm-services.html)
- [ALB Security Policies](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/describe-ssl-policies.html)

### AWS Well-Architected Framework
- [SEC03-BP02: Grant least privilege access](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_least_privileges.html)
- [SEC05-BP02: Control traffic flow within your network layers](https://docs.aws.amazon.com/wellarchitected/2025-02-25/framework/sec_network_protection_layered.html)
- [SEC09-BP01: Implement secure key and certificate management](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_key_cert_mgmt.html)
- [SEC09-BP02: Enforce encryption in transit](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_encrypt.html)

### Module Documentation
- [hashi-demos-apj/alb/aws](https://app.terraform.io/hashi-demos-apj/registry/modules/private/hashi-demos-apj/alb/aws)
- [hashi-demos-apj/ec2-instance/aws](https://app.terraform.io/hashi-demos-apj/registry/modules/private/hashi-demos-apj/ec2-instance/aws)
- [hashi-demos-apj/security-group/aws](https://app.terraform.io/hashi-demos-apj/registry/modules/private/hashi-demos-apj/security-group/aws)

---

## Conclusion

All technical unknowns have been resolved through private registry module research and AWS security best practices review. The implementation approach uses approved private modules, follows organizational security standards, and optimizes for development environment cost constraints while maintaining production-ready security patterns.

**Next Steps**: Proceed to Phase 1 design (plan.md, data-model.md, contracts/).
