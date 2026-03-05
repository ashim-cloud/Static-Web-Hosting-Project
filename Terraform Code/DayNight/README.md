# DayNight Terraform Infrastructure

Terraform project for two AWS environments (`uat`, `prod`) with static website hosting, CloudFront, invalidation Lambda, and CodePipeline-based deployment.

# Set Variables

Read SETUP.md file and Set Variables in Following Files

## Automated Execution Order

Run:

```bash
chmod +x infra-orchestrator.sh
 ./infra-orchestrator.sh
```

## Manual Creation Method

```bash
cd environments/uat
terraform init
terraform apply
# Confirm SNS subscription email, then deploy prod
cd ../prod
terraform init
terraform apply
# Enable UAT pipeline after prod is ready
cd ../uat
terraform apply
```

## Architecture

- UAT creates:
  - S3 static site bucket
  - CloudFront distribution
  - Lambda for CloudFront cache invalidation
  - SNS topic + email subscriptions
  - CodePipeline (only when `enable_pipeline = true`)
- Prod creates:
  - S3 static site bucket
  - CloudFront distribution
  - Lambda for CloudFront cache invalidation
  - CodePipeline (no manual approval stage)
- Prod reads UAT SNS topic ARN from UAT local Terraform state:
  - `environments/prod/main.tf` -> `data.terraform_remote_state.uat`

## Deployment Workflow

1. UAT bootstrap (pipeline disabled)
2. Confirm SNS subscription email
3. Deploy prod
4. Enable UAT pipeline
5. UAT pipeline success notification is sent first
6. UAT manual approval email is sent to trigger prod pipeline
7. On approval, UAT triggers prod pipeline

## Project Structure

```text
DayNight/
+-- environments/
�   +-- uat/
�   �   +-- main.tf
�   �   +-- variables.tf
�   �   +-- terraform.tfvars
�   �   +-- outputs.tf
�   �   +-- terraform.tfstate (local state)
�   +-- prod/
�       +-- main.tf
�       +-- variables.tf
�       +-- terraform.tfvars
�       +-- outputs.tf
�       +-- terraform.tfstate (local state)
+-- modules/
�   +-- s3/
�   �   +-- main.tf
�   �   +-- variables.tf
�   �   +-- outputs.tf
�   +-- cloudfront/
�   �   +-- main.tf
�   �   +-- variables.tf
�   �   +-- outputs.tf
�   +-- lambda-invalidation/
�   �   +-- main.tf
�   �   +-- variables.tf
�   �   +-- versions.tf
�   �   +-- outputs.tf
�   �   +-- cloudfront_invalidator.zip
�   �   +-- lambda/
�   �   �   +-- cloudfront_invalidator.py
�   �   +-- src/
�   �       +-- cloudfront_invalidator/
�   �           +-- index.py
�   +-- sns-notifications/
�   �   +-- main.tf
�   �   +-- variables.tf
�   �   +-- outputs.tf
�   +-- codepipeline/
�       +-- main.tf
�       +-- variables.tf
�       +-- outputs.tf
+-- README.md
+-- SETUP.md
```

## Key Behavior

- Local backend is used by default (no backend blocks).
- UAT pipeline resource is controlled by:
  - `environments/uat/terraform.tfvars` -> `enable_pipeline`
- UAT pipeline sends notifications to UAT SNS:
  - success message with CloudFront link
  - failure message with failed stage/action
  - approval message to trigger prod pipeline
- Prod pipeline source auto-detection is disabled:
  - `source_detect_changes = false`

## Important Variables

UAT (`environments/uat/terraform.tfvars`):
- `aws_region`
- `project_name`
- `github_owner`
- `github_repo`
- `github_branch`
- `notification_emails`
- `enable_pipeline`
- `tags` (must include `Application`, `Owner`, `Environment`, `ManagedBy`)

Prod (`environments/prod/terraform.tfvars`):
- `aws_region`
- `project_name`
- `github_owner`
- `github_repo`
- `github_branch`
- `tags` (must include `Application`, `Owner`, `Environment`, `ManagedBy`)

## Outputs

UAT outputs (`environments/uat/outputs.tf`):
- `uat_s3_bucket_name`
- `uat_cloudfront_domain_name`
- `uat_pipeline_name`
- `uat_sns_topic_name`
- `uat_sns_topic_arn`
- `uat_sns_subscription_emails`
- `uat_sns_subscription_arns`

Prod outputs (`environments/prod/outputs.tf`):
- `prod_s3_bucket_name`
- `prod_cloudfront_domain_name`
- `prod_pipeline_name`

## Notes

- Prod depends on UAT state for SNS ARN. If UAT state is missing/destroyed, prod plan/apply will fail until UAT is recreated.
- S3 bucket names are forced lowercase in module logic.
