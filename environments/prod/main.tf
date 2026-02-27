# Find CodeConnections resources by the Application tag.
data "aws_resourcegroupstaggingapi_resources" "codestar_connections" {
  tag_filter {
    key    = "Application"
    values = [var.tags["Application"]] # Searching By Application Tag to find GitHub Connetions ARN for pipeline module.
  }
}

# Read UAT outputs from local state file to reuse SNS topic ARN in prod pipeline.
data "terraform_remote_state" "uat" {
  backend = "local"

  config = {
    path = abspath("${path.module}/../uat/terraform.tfstate")
  }
}

# Build common names/tags and pick exactly one connection ARN.
locals {
  common_tags = var.tags
  site_bucket_base_name = "${var.project_name}-prod"

  codestar_connection_arns = sort([
    for r in data.aws_resourcegroupstaggingapi_resources.codestar_connections.resource_tag_mapping_list :
    r.resource_arn
    if(
      (can(regex(":codeconnections:", r.resource_arn)) || can(regex(":codestar-connections:", r.resource_arn)))
      && can(regex(":connection/", r.resource_arn))
    )
  ])

  codestar_connection_arn = one(local.codestar_connection_arns)
}

# Create Website bucket for prod. With force_destroy=true allows bucket removal with objects.
module "s3_site" {
  source = "../../modules/s3"

  bucket_name   = local.site_bucket_base_name
  force_destroy = true # Delete bucket with objects when destroying.
  tags          = local.common_tags # Owner,Application,Environment,ManagedBy Tags
}

# CloudFront in front of the S3 website bucket.
module "cloudfront" {
  source = "../../modules/cloudfront"

  distribution_name           = "${var.project_name}-prod-cdn"
  bucket_name                 = module.s3_site.bucket_name
  bucket_regional_domain_name = module.s3_site.bucket_regional_domain_name
  tags                        = local.common_tags # Owner,Application,Environment,ManagedBy Tags
}

# Lambda used by pipeline to invalidate CloudFront cache after deploy.
module "lambda_invalidation" {
  source = "../../modules/lambda-invalidation"

  function_name   = "${var.project_name}-prod-cf-invalidator"
  distribution_id = module.cloudfront.distribution_id
  tags            = local.common_tags # Owner,Application,Environment,ManagedBy Tags
}

# Prod pipeline uses SNS topic ARN from UAT state and runs without manual approval stage.
module "codepipeline" {
  source = "../../modules/codepipeline"

  pipeline_name          = "${var.project_name}-prod-pipeline"
  connection_arn         = local.codestar_connection_arn
  github_owner           = var.github_owner
  github_repo            = var.github_repo
  github_branch          = var.github_branch
  app_bucket_name        = module.s3_site.bucket_name
  lambda_function_name   = module.lambda_invalidation.function_name
  sns_topic_arn          = data.terraform_remote_state.uat.outputs.uat_sns_topic_arn
  cloudfront_domain_name = module.cloudfront.domain_name
  enable_manual_approval = false
  # Stop automatic executions from source change detection.
  source_detect_changes  = false
  tags                   = local.common_tags # Owner,Application,Environment,ManagedBy Tags

  # Force infra prerequisites to exist before pipeline creation to reduce first-run race issues.
  depends_on = [
    module.s3_site,
    module.cloudfront,
    module.lambda_invalidation
  ]
}
