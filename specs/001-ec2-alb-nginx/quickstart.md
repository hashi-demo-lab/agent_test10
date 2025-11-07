# Quick Deployment Guide: EC2 with ALB and Nginx

**Feature**: EC2 Infrastructure with ALB and Nginx
**Deployment Time**: ~15 minutes
**Cost Estimate**: ~$45/month (development environment)

---

## Prerequisites

Before deploying this infrastructure, ensure you have:

### 1. HCP Terraform Access

- [x] Account in HCP Terraform organization: `hashi-demos-apj`
- [x] Access to project: `sandbox`
- [x] Workspace: `sandbox_ec2-alb-nginx` (will be created during testing)
- [x] `TFE_TOKEN` environment variable configured (authentication)

### 2. AWS Prerequisites

- [x] AWS account with access to ap-southeast-2 region
- [x] Default VPC exists in ap-southeast-2 (created automatically in all regions)
- [x] ACM certificate in ap-southeast-2 region (for HTTPS) **OR** willingness to create one
- [x] AWS credentials configured as workspace variable set in HCP Terraform

### 3. Local Development Tools

- [x] Terraform CLI >= 1.8 installed ([download](https://developer.hashicorp.com/terraform/downloads))
- [x] Git installed and configured
- [x] GitHub CLI (`gh`) installed ([download](https://cli.github.com/))
- [x] Text editor or IDE

---

## Step 1: Clone and Setup Repository

```bash
# Clone repository (if not already cloned)
git clone <repository-url>
cd <repository-name>

# Checkout feature branch
git checkout 001-ec2-alb-nginx

# Verify branch
git branch --show-current
# Output: 001-ec2-alb-nginx
```

---

## Step 2: Obtain or Create ACM Certificate

### Option A: Use Existing Certificate

If you have an existing ACM certificate in ap-southeast-2:

```bash
# List certificates in ap-southeast-2
aws acm list-certificates --region ap-southeast-2 --output table

# Copy the Certificate ARN for use in variables
```

### Option B: Create New ACM Certificate

```bash
# Request certificate via AWS CLI
aws acm request-certificate \
  --domain-name "*.example.com" \
  --validation-method DNS \
  --region ap-southeast-2

# Output will include Certificate ARN - copy this value

# Follow DNS validation instructions to complete certificate issuance
# Certificate status must be "ISSUED" before proceeding
```

**Note**: For development/testing, you can use a self-signed certificate or request a certificate for any domain. The ALB DNS name will work regardless of the certificate domain (though browsers will show warnings if domain doesn't match).

---

## Step 3: Configure Terraform Variables

### Create `sandbox.auto.tfvars` File

```bash
# Copy example file
cp sandbox.auto.tfvars.example sandbox.auto.tfvars

# Edit with your values
nano sandbox.auto.tfvars
```

### Required Variable Values

```hcl
# sandbox.auto.tfvars

# Environment
environment = "development"

# AWS Region
region = "ap-southeast-2"

# EC2 Configuration
instance_type = "t3.micro"  # Or "t4g.micro" for 20% cost savings

# ACM Certificate ARN (replace with your certificate)
certificate_arn = "arn:aws:acm:ap-southeast-2:ACCOUNT_ID:certificate/CERTIFICATE_ID"

# Common Tags
common_tags = {
  Environment = "development"
  Project     = "ec2-alb-nginx"
  ManagedBy   = "Terraform"
  Owner       = "your-email@example.com"
}
```

---

## Step 4: Initialize Terraform

```bash
# Configure Terraform Cloud credentials
mkdir -p ~/.terraform.d && cat > ~/.terraform.d/credentials.tfrc.json << EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "${TFE_TOKEN}"
    }
  }
}
EOF

# Initialize Terraform (downloads providers and modules)
terraform init

# Expected output:
# Terraform has been successfully initialized!
```

**What This Does**:
- Downloads AWS provider (version ~> 6.0)
- Downloads private registry modules (alb, ec2-instance, security-group)
- Configures HCP Terraform Cloud backend
- Creates `.terraform` directory with dependencies

---

## Step 5: Validate Configuration

```bash
# Format code (apply HashiCorp style guide)
terraform fmt -recursive

# Validate syntax
terraform validate

# Expected output:
# Success! The configuration is valid.
```

---

## Step 6: Review Execution Plan

```bash
# Generate execution plan
terraform plan

# Review output carefully:
# - Resources to be created: ~10-15 resources
# - ALB with HTTPS listener and target group
# - 2 EC2 instances (1 per AZ)
# - Security groups and IAM roles
# - No unexpected changes or deletions
```

**Key Resources in Plan**:
- Application Load Balancer
- ALB Target Group (HTTP health checks)
- 2 × EC2 instances with Nginx user data
- Security groups (ALB and EC2)
- IAM instance profile with SSM permissions

---

## Step 7: Deploy Infrastructure

### Option A: HCP Terraform UI (Recommended)

```bash
# Commit and push changes (triggers VCS workflow)
git add .
git commit -m "Deploy EC2 ALB Nginx infrastructure

- 2 EC2 instances across 2 AZs
- ALB with HTTPS termination
- Defense-in-depth security groups
- Nginx web server via user data

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin 001-ec2-alb-nginx

# HCP Terraform will automatically:
# 1. Detect commit
# 2. Run terraform plan
# 3. Wait for manual approval
# 4. Run terraform apply (after approval)
```

Navigate to HCP Terraform UI:
1. Open workspace: `sandbox_ec2-alb-nginx`
2. Review plan in UI
3. Click "Confirm & Apply" when ready
4. Monitor apply progress in UI

### Option B: Terraform CLI (Testing)

```bash
# Apply using Terraform CLI with cloud backend
terraform apply

# Review plan output
# Type 'yes' to confirm

# Wait ~10-15 minutes for infrastructure provisioning
```

---

## Step 8: Verify Deployment

### Check Outputs

```bash
# Display Terraform outputs
terraform output

# Expected outputs:
# alb_dns_name = "sandbox-alb-123456789.ap-southeast-2.elb.amazonaws.com"
# ec2_instance_ids = [
#   "i-0123456789abcdef0",
#   "i-0123456789abcdef1"
# ]
# alb_arn = "arn:aws:elasticloadbalancing:ap-southeast-2:..."
```

### Test ALB Endpoint

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTPS endpoint (may show certificate warning if domain doesn't match)
curl -k https://$ALB_DNS

# Expected response: Nginx welcome page HTML
```

### Verify Health Checks

```bash
# Check target group health via AWS CLI
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region ap-southeast-2

# Expected output:
# All targets should show State: "healthy"
```

### Access Instances via Systems Manager

```bash
# List EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=development" \
  --region ap-southeast-2 \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table

# Start Session Manager session (no SSH required!)
aws ssm start-session \
  --target <instance-id> \
  --region ap-southeast-2

# Once connected, verify Nginx is running:
sudo systemctl status nginx
curl http://localhost/health
# Expected output: "OK"
```

---

## Step 9: Access Your Web Application

### Via Browser

1. Copy ALB DNS name from outputs: `terraform output -raw alb_dns_name`
2. Open in browser: `https://<alb-dns-name>`
3. Accept certificate warning (if self-signed or domain mismatch)
4. You should see Nginx welcome page with instance information

### Via Command Line

```bash
# HTTPS request (production traffic flow)
curl -k https://$(terraform output -raw alb_dns_name)

# Test health check endpoint
curl -k https://$(terraform output -raw alb_dns_name)/health
# Expected output: "OK"

# HTTP request (should redirect to HTTPS)
curl -I http://$(terraform output -raw alb_dns_name)
# Expected response: HTTP 301 with Location: https://...
```

---

## Step 10: Monitor Infrastructure

### CloudWatch Metrics

```bash
# View ALB request count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=$(terraform output -raw alb_arn | cut -d':' -f6 | cut -d'/' -f2-4) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region ap-southeast-2
```

### View Target Health Dashboard

Navigate to AWS Console:
1. EC2 → Load Balancers
2. Select your ALB
3. View "Target Groups" tab
4. Check health status of registered instances

---

## Cost Optimization Tips

### Current Monthly Cost Estimate

| Resource | Quantity | Unit Cost | Monthly Cost |
|----------|----------|-----------|--------------|
| t3.micro instances | 2 | $9.64 | $19.28 |
| Application Load Balancer | 1 | ~$22 | $22.00 |
| Data transfer (estimate) | - | - | ~$3.00 |
| **Total** | | | **~$44.28/month** |

### Cost Reduction Options

**Option 1: Use Graviton Instances (20% savings)**
```hcl
# In sandbox.auto.tfvars
instance_type = "t4g.micro"  # Instead of "t3.micro"

# Monthly savings: ~$3.80 (20% reduction on EC2 costs)
```

**Option 2: Instance Scheduling (70% savings on EC2)**
- Run instances only during business hours (e.g., weekdays 8 AM - 6 PM)
- Potential savings: ~$13/month on EC2 costs
- Requires implementing EC2 Instance Scheduler (Lambda function)

**Option 3: Use Spot Instances for Development (70-90% savings on EC2)**
- Not recommended for this ALB-integrated setup
- Better for Auto Scaling groups with mixed instance types

---

## Troubleshooting

### Issue: Certificate ARN Invalid

**Symptom**: Terraform plan fails with "Invalid certificate ARN"

**Solution**:
```bash
# Verify certificate exists in correct region
aws acm list-certificates --region ap-southeast-2

# Ensure certificate status is "ISSUED"
aws acm describe-certificate \
  --certificate-arn <your-arn> \
  --region ap-southeast-2 \
  --query 'Certificate.Status'

# Update sandbox.auto.tfvars with correct ARN
```

### Issue: Health Checks Failing

**Symptom**: Target group shows "unhealthy" instances

**Solution**:
```bash
# SSH into instance via Systems Manager
aws ssm start-session --target <instance-id> --region ap-southeast-2

# Check Nginx status
sudo systemctl status nginx

# Verify health check endpoint exists
curl http://localhost/health

# Check security group allows traffic from ALB
# Ensure EC2 security group allows HTTP from ALB security group
```

### Issue: Cannot Access ALB via HTTPS

**Symptom**: Connection timeout or refused when accessing ALB

**Solution**:
```bash
# Verify ALB security group allows HTTPS from internet
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*alb-sg*" \
  --region ap-southeast-2 \
  --query 'SecurityGroups[*].IpPermissions'

# Expected: Rule allowing TCP/443 from 0.0.0.0/0

# Check ALB listener configuration
aws elbv2 describe-listeners \
  --load-balancer-arn $(terraform output -raw alb_arn) \
  --region ap-southeast-2
```

### Issue: EC2 Instances Not Registering with Target Group

**Symptom**: Target group shows "unused" or instances missing

**Solution**:
```bash
# Check if instances are running
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=development" \
  --region ap-southeast-2 \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'

# Verify target group attachments
terraform state list | grep aws_lb_target_group_attachment

# Re-run terraform apply to recreate attachments if missing
terraform apply -target=module.alb
```

---

## Cleanup / Destroy Infrastructure

### Important: Cost Savings

When not actively using this infrastructure, destroy it to avoid unnecessary costs:

```bash
# Destroy all infrastructure
terraform destroy

# Review resources to be destroyed
# Type 'yes' to confirm

# Wait ~5-10 minutes for complete destruction
```

### Verify Cleanup

```bash
# Check for remaining resources
aws elbv2 describe-load-balancers \
  --region ap-southeast-2 \
  --query 'LoadBalancers[?starts_with(LoadBalancerName, `sandbox`)].LoadBalancerName'

# Expected output: Empty array []

aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=development" \
  --region ap-southeast-2 \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'

# Expected output: No instances or all in "terminated" state
```

---

## Next Steps

### Production Deployment

To deploy this infrastructure to production:

1. **Create production workspace** in HCP Terraform (pre-provisioned by platform team)
2. **Update variables** for production environment (larger instance types, etc.)
3. **Add Auto Scaling** for dynamic capacity management
4. **Implement custom domain** with Route53 DNS records
5. **Enable ALB access logs** to S3 for audit trail
6. **Add CloudWatch alarms** for monitoring and alerting
7. **Configure VPC Flow Logs** for network traffic analysis

### Security Enhancements

- Add AWS WAF for application-layer protection
- Implement AWS Shield for DDoS protection
- Enable GuardDuty for threat detection
- Add AWS Config rules for compliance monitoring

### Operational Improvements

- Set up CloudWatch dashboards for visibility
- Configure SNS alerts for health check failures
- Implement backup strategy for instance data (if stateful)
- Document runbooks for common operations

---

## Support and Resources

### Documentation

- [HCP Terraform Workspace](https://app.terraform.io/app/hashi-demos-apj/workspaces/sandbox_ec2-alb-nginx)
- [Feature Specification](./spec.md)
- [Implementation Plan](./plan.md)
- [Data Model](./data-model.md)
- [Research Decisions](./research.md)

### AWS Documentation

- [Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [ACM User Guide](https://docs.aws.amazon.com/acm/)
- [Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

### Get Help

- **Platform Team**: Contact for module support or workspace provisioning
- **GitHub Issues**: Report bugs or request features
- **Terraform Module Registry**: View module documentation and examples

---

## Deployment Checklist

Use this checklist to ensure successful deployment:

- [ ] HCP Terraform access configured (organization, project, workspace)
- [ ] `TFE_TOKEN` environment variable set
- [ ] ACM certificate created and in "ISSUED" status
- [ ] `sandbox.auto.tfvars` configured with correct values
- [ ] Terraform initialized successfully (`terraform init`)
- [ ] Configuration validated (`terraform validate`)
- [ ] Execution plan reviewed (`terraform plan`)
- [ ] Infrastructure deployed (`terraform apply`)
- [ ] Outputs verified (ALB DNS name, instance IDs)
- [ ] Health checks passing (all targets healthy)
- [ ] HTTPS endpoint accessible via browser
- [ ] Nginx serving content successfully
- [ ] CloudWatch metrics visible in console
- [ ] Documentation updated with actual values
- [ ] Cost estimate reviewed and approved
- [ ] Cleanup plan documented (for development environments)

---

**Deployment Time**: Approximately **15 minutes** from start to finish.

**Success Criteria**: ALB DNS name accessible via HTTPS, both EC2 instances healthy, Nginx serving content.
