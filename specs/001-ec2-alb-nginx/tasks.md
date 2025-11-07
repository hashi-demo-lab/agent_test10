# Tasks: EC2 Infrastructure with ALB and Nginx

**Input**: Design documents from `/specs/001-ec2-alb-nginx/`
**Prerequisites**: plan.md, spec.md, data-model.md, research.md, quickstart.md
**Feature**: Deploy high-availability web infrastructure across 2 AZs with EC2 instances, Nginx, and ALB with HTTPS termination

**Tests**: This is infrastructure deployment - validation will be via Terraform validation, pre-commit hooks, and live infrastructure testing.

**Organization**: Tasks are grouped by user story to enable independent implementation and validation of infrastructure components.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Terraform configuration structure

- [ ] T001 Create project structure with main.tf, variables.tf, outputs.tf, providers.tf, terraform.tf, locals.tf at repository root
- [ ] T002 Install pre-commit framework if not already present using pip or system package manager
- [ ] T003 Update .git/hooks/pre-commit to execute pre-commit framework hooks
- [ ] T004 Verify .pre-commit-config.yaml exists with terraform_fmt, terraform_docs, terraform_validate, checkov, and tflint hooks
- [ ] T005 Create .gitignore file with Terraform-specific exclusions (*.tfstate, *.tfvars, .terraform/)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Terraform configuration that MUST be complete before ANY infrastructure resources can be provisioned

**⚠️ CRITICAL**: No infrastructure provisioning can begin until this phase is complete

- [ ] T006 Define Terraform and provider version constraints in terraform.tf (Terraform >= 1.8, AWS >= 6.0)
- [ ] T007 Configure AWS provider with region in providers.tf
- [ ] T008 [P] Define input variables in variables.tf: region, environment, instance_type, certificate_arn, availability_zones, common_tags with validation rules
- [ ] T009 [P] Define local values in locals.tf: common_tags map, availability zone list, computed naming values
- [ ] T010 Create override.tf with HCP Terraform cloud backend configuration (org: hashi-demos-apj, workspace: sandbox_ec2-alb-nginx, project: sandbox)
- [ ] T011 Create sandbox.auto.tfvars.example template file with example values for all required variables
- [ ] T012 Run terraform init to download providers and modules, verify initialization succeeds
- [ ] T013 Run terraform validate to verify configuration syntax, fix any validation errors
- [ ] T014 Run terraform fmt -recursive to format all Terraform files
- [ ] T015 Run pre-commit run --all-files to execute all configured hooks, fix any issues reported

**Checkpoint**: Foundation ready - infrastructure provisioning can now begin

---

## Phase 3: User Story 1 - Deploy High-Availability Web Infrastructure (Priority: P1) 🎯 MVP

**Goal**: Provision EC2 instances across 2 availability zones with load balancer distributing traffic for fault tolerance

**Independent Test**: Deploy infrastructure, verify instances running in separate AZs, confirm load balancer distributes traffic to both zones

### Data Sources (User Story 1)

- [ ] T016 [P] [US1] Create data source for default VPC lookup in main.tf using aws_vpc with default=true filter
- [ ] T017 [P] [US1] Create data source for default subnets lookup in main.tf using aws_subnets filtered by VPC ID
- [ ] T018 [P] [US1] Create data source for latest Amazon Linux 2023 AMI in main.tf using SSM parameter /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64

### Security Groups (User Story 1)

- [ ] T019 [P] [US1] Declare alb_security_group module in main.tf using app.terraform.io/hashi-demos-apj/security-group/aws v5.3.1 with HTTPS ingress from 0.0.0.0/0
- [ ] T020 [P] [US1] Declare ec2_security_group module in main.tf using app.terraform.io/hashi-demos-apj/security-group/aws v5.3.1 with HTTP ingress from ALB security group only

### IAM Role (User Story 1)

- [ ] T021 [US1] Configure IAM instance profile creation in ec2-instance module with AmazonSSMManagedInstanceCore policy for Systems Manager Session Manager access

### EC2 Instances (User Story 1)

- [ ] T022 [US1] Create user data script in locals.tf for Nginx installation: dnf update, dnf install nginx, systemctl start/enable nginx, create /health endpoint
- [ ] T023 [P] [US1] Declare ec2_instance_az_a module in main.tf using app.terraform.io/hashi-demos-apj/ec2-instance/aws v6.1.4 for ap-southeast-2a with t3.micro instance type, Nginx user data, encrypted EBS volume, detailed monitoring enabled
- [ ] T024 [P] [US1] Declare ec2_instance_az_b module in main.tf using app.terraform.io/hashi-demos-apj/ec2-instance/aws v6.1.4 for ap-southeast-2b with t3.micro instance type, Nginx user data, encrypted EBS volume, detailed monitoring enabled

### Application Load Balancer (User Story 1)

- [ ] T025 [US1] Declare ALB module in main.tf using app.terraform.io/hashi-demos-apj/alb/aws v10.1.0 with internet-facing configuration, multi-AZ subnet placement
- [ ] T026 [US1] Configure target group in ALB module with HTTP protocol port 80, health check path /health, interval 30s, healthy threshold 3, unhealthy threshold 2
- [ ] T027 [US1] Register EC2 instance from az_a with target group using create_attachment in target_groups configuration
- [ ] T028 [US1] Register EC2 instance from az_b with target group using create_attachment in target_groups configuration
- [ ] T029 [US1] Enable ALB features: deletion_protection=true, cross_zone_load_balancing=true, http2=true, drop_invalid_header_fields=true

### Outputs (User Story 1)

- [ ] T030 [P] [US1] Define outputs in outputs.tf: alb_dns_name (ALB endpoint), alb_arn, target_group_arn, ec2_instance_ids (list), ec2_instance_private_ips (list), alb_security_group_id, ec2_security_group_id, iam_role_arn

**Checkpoint**: At this point, high-availability infrastructure should be deployed with instances in 2 AZs and traffic distribution via ALB

---

## Phase 4: User Story 2 - Secure HTTPS Access to Web Services (Priority: P1)

**Goal**: Encrypt all web traffic using HTTPS with valid SSL/TLS certificate and secure TLS versions

**Independent Test**: Access load balancer endpoint via HTTPS, verify SSL/TLS certificate valid, confirm traffic encrypted

### HTTPS Listener Configuration (User Story 2)

- [ ] T031 [US2] Add certificate_arn variable to variables.tf with validation ensuring ARN matches ACM certificate format (^arn:aws:acm:)
- [ ] T032 [US2] Configure HTTPS listener in ALB module listeners block: port 443, protocol HTTPS, certificate_arn from variable, ssl_policy ELBSecurityPolicy-TLS13-1-2-2021-06 (TLS 1.2/1.3 only)
- [ ] T033 [US2] Configure HTTPS listener to forward traffic to target group ec2_targets
- [ ] T034 [US2] Configure HTTP listener in ALB module on port 80 with redirect to HTTPS port 443 with status code HTTP_301

### Outputs (User Story 2)

- [ ] T035 [US2] Add certificate_arn output to outputs.tf to document which certificate is in use

**Checkpoint**: HTTPS access should be enabled with valid certificate, HTTP traffic redirected to HTTPS, only TLS 1.2+ permitted

---

## Phase 5: User Story 3 - Serve Web Content via Nginx (Priority: P2)

**Goal**: Install and configure Nginx web server on EC2 instances to serve application content

**Independent Test**: Send HTTP requests to instance endpoints, verify Nginx responds with expected content

### Nginx Configuration (User Story 3)

- [ ] T036 [US3] Enhance user data script in locals.tf to create custom Nginx welcome page showing availability zone and instance ID using ec2-metadata commands
- [ ] T037 [US3] Add health check endpoint /health in user data script with "OK" response
- [ ] T038 [US3] Verify Nginx configuration in user data sets service to start automatically on instance boot (systemctl enable nginx)

**Checkpoint**: Nginx should be installed, running, auto-starting on boot, and serving custom content with health check endpoint

---

## Phase 6: User Story 4 - Minimize Infrastructure Costs for Development (Priority: P3)

**Goal**: Use cost-optimized resources balancing functionality with minimal expense for development environment

**Independent Test**: Review deployed resource specifications, calculate estimated monthly costs against development budget (<$100/month)

### Cost Optimization (User Story 4)

- [ ] T039 [US4] Validate instance_type variable in variables.tf accepts t3.micro or t4g.micro with validation rule
- [ ] T040 [US4] Document cost optimization in README.md: t3.micro $9.64/instance/month, t4g.micro $7.74/instance/month (20% savings), ALB ~$22/month base charge
- [ ] T041 [US4] Verify instance count is 2 (minimal for HA) to avoid over-provisioning
- [ ] T042 [US4] Add cost estimation tags to common_tags in locals.tf: Environment, Owner, Application, ManagedBy

**Checkpoint**: Infrastructure should use smallest viable instance types (t3.micro default), minimal instance count (2), estimated monthly cost ~$45 (well under $100 budget)

---

## Phase 7: Validation & Testing

**Purpose**: Validate infrastructure configuration and prepare for deployment

### Pre-Deployment Validation

- [ ] T043 Run terraform validate to verify all configuration syntax
- [ ] T044 Run terraform fmt -check to verify all files formatted correctly
- [ ] T045 Run pre-commit run --all-files to execute terraform_validate, checkov, tflint, tfsec security checks
- [ ] T046 Review and address any security findings from checkov and tfsec (no suppression without justification)
- [ ] T047 Create sandbox.auto.tfvars file with runtime variable values for testing (not committed to git)

### Ephemeral Workspace Testing

- [ ] T048 Commit all Terraform code to feature branch 001-ec2-alb-nginx
- [ ] T049 Push feature branch to remote GitHub repository
- [ ] T050 Get repository name using gh repo view --json name -q .name for workspace naming
- [ ] T051 Create ephemeral HCP Terraform workspace using Terraform MCP server: workspace name sandbox_<REPO_NAME>, organization hashi-demos-apj, project sandbox, auto_apply=true, auto_destroy_at=2 hours
- [ ] T052 Analyze variables.tf to identify all required variables for workspace variable creation
- [ ] T053 Create workspace variables in ephemeral workspace based on sandbox.auto.tfvars (exclude cloud provider credentials - pre-configured at workspace level)
- [ ] T054 Execute terraform plan against ephemeral workspace using Terraform CLI with cloud backend, review plan output for any issues
- [ ] T055 Monitor terraform apply auto-execution (triggered by auto_apply setting), verify successful completion
- [ ] T056 Validate deployed infrastructure: verify instances running in 2 AZs, health checks passing, ALB endpoint accessible via HTTPS
- [ ] T057 Test HTTPS endpoint: curl -k https://<alb-dns-name>, verify Nginx response with availability zone and instance ID
- [ ] T058 Test health check endpoint: curl -k https://<alb-dns-name>/health, verify "OK" response
- [ ] T059 Verify target group health: aws elbv2 describe-target-health, confirm all instances show State: healthy
- [ ] T060 Test Systems Manager Session Manager access to instances, verify Nginx service status: systemctl status nginx
- [ ] T061 Prompt user to validate created resources in AWS Console
- [ ] T062 After user validation, create identical workspace variables in sandbox workspace for future deployments
- [ ] T063 Delete ephemeral workspace to minimize costs (auto-destroy will cleanup if not manually deleted)

### Error Remediation (if needed)

- [ ] T064 If terraform validate fails: analyze errors, fix configuration issues, re-run validation
- [ ] T065 If pre-commit hooks fail: address linting/security findings, commit fixes, re-run hooks
- [ ] T066 If terraform plan fails: analyze variable values, module sources, provider authentication, fix issues, re-run plan
- [ ] T067 If terraform apply fails: analyze resource creation errors (quota limits, permissions, network issues), fix issues, re-run apply
- [ ] T068 If health checks fail: verify Nginx installed/running, health endpoint exists, security groups allow ALB → EC2 traffic on port 80

**Checkpoint**: All validation passing, ephemeral workspace deployment successful, infrastructure fully functional

---

## Phase 8: Documentation & Polish

**Purpose**: Document infrastructure for production use and future maintenance

- [ ] T069 [P] Generate README.md documentation using terraform-docs via pre-commit hook
- [ ] T070 [P] Update README.md with deployment instructions from quickstart.md
- [ ] T071 [P] Document required variables in README.md: environment, region, instance_type, certificate_arn, common_tags
- [ ] T072 [P] Document prerequisites in README.md: HCP Terraform access, ACM certificate, AWS credentials
- [ ] T073 [P] Add troubleshooting section to README.md: certificate ARN validation, health check failures, security group issues
- [ ] T074 Document cost optimization options in README.md: Graviton instances (t4g.micro), instance scheduling for development
- [ ] T075 Add architecture diagram to README.md or docs/ showing VPC, subnets, ALB, EC2 instances, security groups, traffic flow
- [ ] T076 Document cleanup instructions in README.md: terraform destroy command, resource verification
- [ ] T077 Run quickstart.md validation to ensure deployment guide is accurate and complete

**Checkpoint**: Infrastructure fully documented with deployment guide, troubleshooting, cost optimization, and cleanup instructions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all infrastructure provisioning
- **User Story 1 (Phase 3)**: Depends on Foundational phase completion - Core infrastructure deployment
- **User Story 2 (Phase 4)**: Depends on User Story 1 completion - HTTPS configuration requires ALB from US1
- **User Story 3 (Phase 5)**: Depends on User Story 1 completion - Nginx configuration enhances EC2 instances from US1
- **User Story 4 (Phase 6)**: Can run in parallel with other user stories - Cost optimization is cross-cutting
- **Validation (Phase 7)**: Depends on all user stories being complete
- **Documentation (Phase 8)**: Depends on validation completion

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories - Deploys core infrastructure (EC2, ALB, security groups)
- **User Story 2 (P1)**: Depends on User Story 1 - HTTPS listener configuration requires ALB resource from US1
- **User Story 3 (P2)**: Depends on User Story 1 - Nginx configuration enhances EC2 instances from US1
- **User Story 4 (P3)**: Can run in parallel with other stories - Cost optimization affects variable defaults and tagging

### Within Each User Story

- **User Story 1**: Data sources → Security groups → EC2 instances → ALB configuration → Outputs
- **User Story 2**: Variable definition → HTTPS listener → HTTP redirect → Outputs
- **User Story 3**: User data script enhancement → Nginx configuration
- **User Story 4**: Variable validation → Cost documentation → Tagging

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel within Phase 2
- Within User Story 1:
  - Data sources (T016, T017, T018) can run in parallel
  - Security groups (T019, T020) can run in parallel after data sources
  - EC2 instances (T023, T024) can run in parallel after security groups
  - Outputs (T030) can be defined in parallel with resource declarations
- All documentation tasks marked [P] in Phase 8 can run in parallel

---

## Parallel Example: User Story 1 - Infrastructure Resources

```bash
# Launch all data sources together:
Task: "Create data source for default VPC lookup in main.tf"
Task: "Create data source for default subnets lookup in main.tf"
Task: "Create data source for latest Amazon Linux 2023 AMI in main.tf"

# After data sources complete, launch security groups together:
Task: "Declare alb_security_group module in main.tf"
Task: "Declare ec2_security_group module in main.tf"

# After security groups complete, launch EC2 instances together:
Task: "Declare ec2_instance_az_a module in main.tf"
Task: "Declare ec2_instance_az_b module in main.tf"
```

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all infrastructure)
3. Complete Phase 3: User Story 1 (High-Availability Infrastructure)
4. Complete Phase 4: User Story 2 (HTTPS Security)
5. **STOP and VALIDATE**: Test infrastructure deployment, verify HTTPS access
6. Deploy to ephemeral workspace for validation

**Rationale**: User Stories 1 and 2 are both P1 priority and deliver core infrastructure with secure HTTPS access. This is the minimal viable infrastructure for production use.

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test infrastructure deployment (EC2, ALB, multi-AZ)
3. Add User Story 2 → Test HTTPS access with certificate
4. Add User Story 3 → Test Nginx content serving
5. Add User Story 4 → Validate cost optimization
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (core infrastructure)
   - Developer B: User Story 2 (HTTPS configuration) - can start after US1 ALB created
   - Developer C: User Story 3 (Nginx configuration) - can start after US1 EC2 created
   - Developer D: User Story 4 (cost optimization) - can start immediately after Foundational
3. Stories complete and integrate with minimal conflicts (different resources/files)

---

## Notes

- [P] tasks = different files or resources, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story delivers independent infrastructure capability
- Terraform modules minimize file conflicts - most tasks work on main.tf but different module declarations
- Commit after each logical group of tasks (e.g., all data sources, all security groups)
- Stop at any checkpoint to validate infrastructure independently
- Security findings from checkov/tfsec MUST be addressed - no suppression without documented justification
- Avoid: Hardcoded values in main.tf (use variables), skipping pre-commit hooks, deploying without validation
- All infrastructure provisioning happens via HCP Terraform Cloud with VCS-driven workflow
- Ephemeral workspace testing is REQUIRED before promotion to sandbox/production workspaces
