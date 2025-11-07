# Implementation Plan: EC2 Infrastructure with ALB and Nginx

**Branch**: `001-ec2-alb-nginx` | **Date**: 2025-11-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-ec2-alb-nginx/spec.md`

## Summary

Deploy high-availability web infrastructure across 2 availability zones in AWS ap-southeast-2 region using EC2 instances with Nginx web server behind an Application Load Balancer providing HTTPS termination. Infrastructure uses private registry modules from hashi-demos-apj organization, implements defense-in-depth security with layered security groups, and optimizes for development environment cost constraints (target: <$100/month).

**Technical Approach**: Use approved private registry modules (`alb/aws`, `ec2-instance/aws`, `security-group/aws`) with ACM-managed SSL certificates, TLS 1.2/1.3 security policy, IAM instance profiles for AWS service access, and Nginx installation via EC2 user data. Deploy via HCP Terraform Cloud with VCS-driven workflow in organization `hashi-demos-apj`, project `sandbox`.

## Technical Context

**Infrastructure as Code**: Terraform >= 1.8, HCL configuration language
**Cloud Provider**: AWS (Provider >= 6.19 for ALB module compatibility)
**Target Region**: ap-southeast-2 (Sydney, Australia)
**Availability Zones**: ap-southeast-2a, ap-southeast-2b (2-AZ deployment)
**Compute Platform**: Amazon EC2 with Amazon Linux 2023
**Web Server**: Nginx (installed via user data)
**Load Balancer**: AWS Application Load Balancer (Layer 7 HTTP/HTTPS)
**Certificate Management**: AWS Certificate Manager (ACM) with automatic renewal
**Network**: AWS VPC (existing default VPC)
**Access Management**: AWS IAM roles with Systems Manager Session Manager
**Deployment**: HCP Terraform Cloud (organization: hashi-demos-apj, project: sandbox)

**Performance Goals**:
- Infrastructure provisioning: <15 minutes
- Web request latency: <500ms (static content via Nginx)
- Health check response: <5 seconds
- High availability: 99.5% uptime during single AZ failure

**Cost Constraints**:
- Target monthly cost: <$100 for development environment
- Instance type: t3.micro (or t4g.micro for 20% savings)
- Instance count: 2 (1 per AZ, minimal for HA)
- Estimated cost: ~$45/month (2 × t3.micro + ALB base charge)

**Security Constraints**:
- TLS 1.2/1.3 only (no legacy SSL/TLS versions)
- No SSH from internet (0.0.0.0/0:22 prohibited)
- Defense-in-depth security groups (ALB → EC2 via SG references)
- IAM roles only (no long-lived AWS credentials on instances)
- ACM-managed certificates (automatic renewal)

**Scale/Scope**:
- 2 EC2 instances (multi-AZ)
- 1 Application Load Balancer
- 1 Target Group with 2 registered instances
- 2-3 Security Groups (ALB, EC2, optional management)
- 1 IAM role with instance profile

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ 1.1 Module-First Architecture

**Status**: PASS

**Compliance**:
- All infrastructure provisioned through private registry modules
- Module sources: `app.terraform.io/hashi-demos-apj/*`
- Versions explicitly constrained with semantic versioning (`~>`)
- No raw resource declarations

**Modules Used**:
- `app.terraform.io/hashi-demos-apj/alb/aws` v10.1.0
- `app.terraform.io/hashi-demos-apj/ec2-instance/aws` v6.1.4
- `app.terraform.io/hashi-demos-apj/security-group/aws` v5.3.1

### ✅ 1.2 Specification-Driven Development

**Status**: PASS

**Compliance**:
- Complete spec.md with functional requirements (FR-001 through FR-015)
- Success criteria with measurable outcomes (SC-001 through SC-010)
- Comprehensive research.md documenting all technical decisions
- Module selections based on private registry search results
- No assumptions made without specification validation

### ✅ 1.3 Security-First Automation

**Status**: PASS

**Compliance**:
- No static credentials generated or stored in code
- IAM roles attached via instance profiles (no access keys)
- ACM-managed certificates (no private key exposure)
- Encrypted EBS volumes by default (module configuration)
- IMDSv2 enforced by default (ec2-instance module v6.1.4)
- Secrets management via AWS Secrets Manager (if needed for future)

### ✅ 2.1 HCP Terraform Prerequisites

**Status**: PASS

**Configuration Validated**:
- HCP Terraform Organization: `hashi-demos-apj`
- HCP Terraform Project: `sandbox`
- Target Workspace: `sandbox_ec2-alb-nginx` (to be created for testing)
- Authentication: TFE_TOKEN environment variable configured

### ✅ 3.1 Repository Structure

**Status**: PASS

**Structure**: Single-application Terraform configuration (infrastructure-only)

```
/
├── main.tf                    # Module instantiations
├── variables.tf               # Input variable declarations
├── outputs.tf                 # Output declarations
├── providers.tf               # AWS provider configuration
├── terraform.tf               # Terraform and provider version constraints
├── locals.tf                  # Local value definitions
├── override.tf                # HCP Terraform cloud backend for testing
├── sandbox.auto.tfvars        # Runtime variable values for testing
├── sandbox.auto.tfvars.example # Example variable file template
├── README.md                  # Documentation (terraform-docs generated)
└── .gitignore                 # Terraform-specific exclusions
```

### ✅ 3.2 File Organization

**Status**: PASS

**Compliance**:
- Logical file separation by purpose
- Module declarations in main.tf
- Input variables with validation in variables.tf
- Outputs with descriptions in outputs.tf
- Provider configuration isolated in providers.tf
- No monolithic files exceeding 300 lines

### ✅ 3.3 Naming Conventions

**Status**: PASS

**Naming Standards** (HashiCorp conventions):
- Resources: `<purpose>-<resource-type>` (e.g., `alb-security-group`, `web-instance`)
- Variables: `snake_case` (e.g., `vpc_id`, `availability_zones`, `certificate_arn`)
- Modules: `<provider>-<resource>-<purpose>` (from private registry)
- Tags: PascalCase for keys, values per organizational standards

### ✅ 3.4 Variable Management

**Status**: PASS

**Compliance**:
- All variables have descriptions explaining purpose and valid values
- Type constraints specified (no implicit `any`)
- Sensitive variables marked with `sensitive = true`
- Validation blocks for business logic constraints (e.g., region, environment)
- Workspace variable sets leveraged (vault URL, org standards)

### ✅ 3.5 Module Usage Patterns

**Status**: PASS

**Pattern**:
```hcl
module "alb" {
  source  = "app.terraform.io/hashi-demos-apj/alb/aws"
  version = "~> 10.1.0"

  name    = var.alb_name
  vpc_id  = data.aws_vpc.default.id
  subnets = data.aws_subnets.default.ids

  # Required by organizational security policy
  enable_deletion_protection = true
  drop_invalid_header_fields = true

  tags = local.common_tags
}
```

### ✅ IV Security and Compliance

**Status**: PASS

**3.1 Credential Management**:
- No static credentials in code or variables
- IAM roles with instance profiles for EC2 AWS API access
- ACM-managed certificates (no private key distribution)
- Systems Manager Session Manager for instance access (no SSH keys)

**3.2 Security Best Practices**:
- TLS 1.2/1.3 only (`ELBSecurityPolicy-TLS13-1-2-2021-06`)
- Defense-in-depth security groups (layered access control)
- No SSH from internet (0.0.0.0/0:22 prohibited)
- Encrypted EBS volumes by default

**3.3 Secrets Management**:
- No secrets in Terraform code or state
- ACM handles certificate private keys
- Future database credentials via AWS Secrets Manager
- All secret-containing outputs marked `sensitive = true`

**3.4 Least Privilege by Default**:
- IAM role scoped to minimum permissions (SSM, CloudWatch Logs)
- Security groups deny all by default, explicit allow rules
- ALB deletion protection enabled
- Network ACLs follow default deny pattern

### ✅ V Workspace and Environment Management

**Status**: PASS

**4.1 HCP Terraform Workspace Management**:
- Using pre-provisioned sandbox workspace pattern
- No workspace creation for long-term environments
- Ephemeral workspace for testing only (auto-destroy after 2 hours)
- Variable promotion workflow: ephemeral → sandbox → dev

**4.2 Variable Sets**:
- Leveraging org-wide variable sets (vault-authentication, tags-standard)
- Not duplicating variable set values in code
- Application-specific variables defined at workspace level

**4.3 Environment Promotion**:
- Feature branch → dev → staging → main workflow
- Human-in-the-loop review required at each stage
- No direct commits to protected branches

### ✅ VI Code Quality and Maintainability

**Status**: PASS

**5.1 Documentation Requirements**:
- README.md with comprehensive deployment instructions
- Auto-generated documentation via terraform-docs (pre-commit hook)
- Inline comments for complex logic and security rationale
- Module selections justified in research.md

**5.2 Code Style**:
- `terraform fmt` for formatting
- `terraform validate` for syntax validation
- HashiCorp Style Guide compliance
- Alphabetized arguments within blocks

**5.3 Testing and Validation**:
- Pre-commit hooks configured (terraform-docs, terraform fmt, terraform validate, tflint, tfsec)
- Ephemeral workspace testing before promotion
- HCP Terraform plan review in UI
- No pre-commit bypass without authorization

**5.4 Version Control**:
- `.gitignore` excludes Terraform state, lock files, and .tfvars
- Atomic commits per logical change
- No secrets committed to repository

### ✅ VII Operational Excellence

**Status**: PASS

**6.1 State Management**:
- Remote state in HCP Terraform Cloud
- No local backend configurations
- State never committed to version control

**6.2 Dependency Management**:
- Provider versions use pessimistic constraints (`~> 6.0`)
- Module versions explicitly pinned with semantic versioning
- No `latest` or unconstrained versions

**6.3 Cost Optimization**:
- t3.micro instances for development (smallest viable)
- 2 instances minimum for HA (not over-provisioned)
- Target monthly cost: <$100
- Optional: Graviton instances (t4g.micro) for 20% savings

**6.4 Monitoring and Observability**:
- CloudWatch detailed monitoring enabled
- ALB access logs configurable
- Health check metrics via target group
- Tags include Environment, Owner, Application

### ✅ VIII AI Agent Behavior

**Status**: PASS

**8.1 Prerequisites Validation**:
- HCP Terraform org, project, workspace validated
- All prerequisites documented in research.md
- No operations without complete prerequisites

**8.2 Scope Boundaries**:
- Using existing approved modules (in scope)
- No new module creation (out of scope - platform team responsibility)
- Documentation generation (in scope)
- No direct resource creation (out of scope - module-first architecture)

**8.3 Error Handling and Transparency**:
- Used `search_private_modules` to find appropriate modules
- Documented tradeoffs and alternatives in research.md
- No module gaps identified
- Proactive security warnings in plan

**8.4 Learning and Adaptation**:
- Referenced constitution for all decisions
- Organizational patterns followed
- Policy compliance validated

### ✅ X Testing and Validation Framework

**Status**: PASS

**10.1 Ephemeral Workspace Testing**:
- Ephemeral workspace creation planned for validation
- Auto-apply and auto-destroy (2 hours) configured
- Feature branch committed and pushed before workspace creation
- Workspace variables from sandbox.auto.tfvars

**10.2 Automated Testing Workflow**:
- Terraform CLI with cloud backend for initial validation
- Workspace variable creation from variables.tf analysis
- User confirmation for variable values
- Terraform init → validate → plan → apply sequence

**10.3 Variable Management for Testing**:
- Variables derived from variables.tf in feature branch
- No cloud provider credentials (pre-configured at workspace level)
- Sensitive variables marked appropriately
- Variable promotion to sandbox workspace upon success

---

## Constitution Compliance Summary

**Overall Status**: ✅ PASS - All constitution gates satisfied

**Key Compliance Points**:
1. ✅ Module-first architecture (no raw resources)
2. ✅ Private registry modules with version constraints
3. ✅ Security-first design (IAM roles, ACM, defense-in-depth SGs)
4. ✅ HCP Terraform Cloud deployment
5. ✅ Specification-driven development
6. ✅ Pre-commit hooks and testing framework
7. ✅ Cost optimization for development environment

**No violations requiring justification.**

## Project Structure

### Documentation (this feature)

```text
specs/001-ec2-alb-nginx/
├── spec.md              # Feature specification (Phase 0)
├── plan.md              # This file - implementation plan (Phase 1)
├── research.md          # Technical research and decisions (Phase 0)
├── data-model.md        # Infrastructure resource model (Phase 1)
├── quickstart.md        # Quick deployment guide (Phase 1)
├── checklists/
│   └── requirements.md  # Specification quality validation (Phase 0)
└── tasks.md             # Implementation task list (Phase 2 - NOT YET CREATED)
```

### Source Code (repository root)

```text
/
├── main.tf                    # Module declarations
│   ├── Data sources (VPC, subnets, AMI)
│   ├── Security group modules (ALB, EC2)
│   ├── IAM role module
│   ├── EC2 instance modules (multi-AZ)
│   ├── ALB target group module
│   └── ALB module with HTTPS listener
│
├── variables.tf               # Input variable declarations
│   ├── Region and AZ configuration
│   ├── VPC and networking variables
│   ├── Instance configuration (type, AMI, count)
│   ├── ALB configuration (certificate ARN, SSL policy)
│   ├── Security group rules
│   └── Tags and metadata
│
├── outputs.tf                 # Resource outputs
│   ├── ALB DNS name and ARN
│   ├── Target group ARN
│   ├── EC2 instance IDs and private IPs
│   ├── Security group IDs
│   └── IAM role ARN
│
├── providers.tf               # AWS provider configuration
│   └── Provider version constraint and region
│
├── terraform.tf               # Terraform block
│   ├── Required Terraform version (>= 1.8)
│   └── Required provider versions (AWS ~> 6.0)
│
├── locals.tf                  # Local value definitions
│   ├── Common tags
│   ├── Availability zone list
│   └── Computed naming values
│
├── override.tf                # HCP Terraform cloud backend (for testing)
│   └── Cloud backend configuration (org, workspace, project)
│
├── sandbox.auto.tfvars        # Runtime variables for testing
├── sandbox.auto.tfvars.example # Example variable file
├── README.md                  # Project documentation (terraform-docs)
└── .gitignore                 # Terraform-specific exclusions
```

**Structure Decision**: Single Terraform project for infrastructure deployment. This is not a web application with frontend/backend separation - it's infrastructure-as-code only. All Terraform files at repository root following HashiCorp standard layout conventions.

## Complexity Tracking

> No constitution violations requiring justification.

**N/A** - All architecture decisions comply with organizational constitution and best practices. No complexity additions requiring exception approval.
