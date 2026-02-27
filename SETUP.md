# Setup Guide

This guide matches the current Terraform implementation in this repository.

## Prerequisites

- Terraform CLI `>= 1.6`
- AWS account permissions for:
  - S3
  - CloudFront
  - IAM
  - Lambda
  - CodePipeline
  - CodeConnections
  - SNS
  - EventBridge
- Existing CodeConnections connection to GitHub in target region add Tag: Application = Project_Name
- Existing GitHub repository and branch configured in tfvars

## Files to Edit

- `environments/uat/terraform.tfvars`
- `environments/prod/terraform.tfvars`

Required values:
- `aws_region`
- `project_name`
- `github_owner`
- `github_repo`
- `github_branch`
- UAT only: `notification_emails`
- UAT only: `enable_pipeline`
- `tags` map with required keys:
  - `Application`
  - `Owner`
  - `Environment`
  - `ManagedBy`

## Automated Execution Order
chmod +x infra-orchestrator.sh
 ./infra-orchestrator.sh
## Execution Order

### 1) Deploy UAT infra with pipeline disabled

Set in `environments/uat/terraform.tfvars`:

```hcl
enable_pipeline = false
```

Run:

```bash
cd environments/uat
terraform init
terraform apply
```

Result:
- UAT S3, CloudFront, Lambda, SNS are created.
- UAT CodePipeline is not created yet.

### 2) Confirm SNS email subscription

- Open the subscription email from AWS SNS.
- Click **Confirm subscription**.

### 3) Deploy PROD infra

Run:

```bash
cd ../prod
terraform init
terraform apply
```

Result:
- Prod infra is created.
- Prod CodePipeline is created without manual approval stage. It will Execute for the first time without permission = default behavior
- Prod reads SNS topic ARN from UAT state (`../uat/terraform.tfstate`).

### 4) Enable UAT pipeline

Set in `environments/uat/terraform.tfvars`:

```hcl
enable_pipeline = true
```

Run:

```bash
cd ../uat
terraform apply
```

Result:
- UAT CodePipeline is created.
- On UAT success, success email is sent first.
- Then approval email is sent for promoting to prod pipeline.
- On approval, prod pipeline is triggered.

## Notification Behavior

UAT pipeline notifications are sent to UAT SNS email subscribers:
- Success notification with CloudFront URL
- Failure notification with stage/action details
- Promotion approval request to trigger prod pipeline

## Useful Commands

UAT outputs:

```bash
cd environments/uat
terraform output
```

Prod outputs:

```bash
cd environments/prod
terraform output
```

Destroy (environment-specific):

```bash
terraform destroy
```

## Troubleshooting

- Error: unsupported attribute `uat_sns_topic_arn` in prod
  - Cause: UAT state does not contain latest outputs yet.
  - Fix: run `terraform apply` in `environments/uat`, then retry prod.

- Error: invalid SNS ARN in prod
  - Cause: stale placeholder/manual ARN usage.
  - Fix: ensure prod is using remote state output from UAT and UAT state exists.

- Prod apply fails after UAT destroy
  - Cause: prod depends on `../uat/terraform.tfstate` output.
  - Fix: recreate UAT first.