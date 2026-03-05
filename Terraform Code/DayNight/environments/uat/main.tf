# Find CodeConnections resources by the Application tag.
data "aws_resourcegroupstaggingapi_resources" "codestar_connections" {
  tag_filter {
    key    = "Application"
    values = [var.tags["Application"]] # Searching By Application Tag to find GitHub Connetions ARN for pipeline module.
  }
}

# Build common names/tags and pick exactly one connection ARN.
locals {
  common_tags           = var.tags
  site_bucket_base_name = "${var.project_name}-uat"

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

module "sns_notifications" {
  source = "../../modules/sns-notifications"

  topic_name          = "${var.project_name}-uat-notifications"
  email_subscriptions = var.notification_emails
  tags                = local.common_tags # Owner,Application,Environment,ManagedBy Tags
}

# Create Website bucket for UAT. With force_destroy=true allows bucket removal with objects.
module "s3_site" {
  source = "../../modules/s3"

  bucket_name   = local.site_bucket_base_name
  force_destroy = true              # Delete bucket with objects when destroying.
  tags          = local.common_tags # Owner,Application,Environment,ManagedBy Tags
}

# CloudFront in front of the S3 website bucket.
module "cloudfront" {
  source = "../../modules/cloudfront"

  distribution_name           = "${var.project_name}-uat-cdn"
  bucket_name                 = module.s3_site.bucket_name
  bucket_regional_domain_name = module.s3_site.bucket_regional_domain_name
  tags                        = local.common_tags # Owner,Application,Environment,ManagedBy Tags
}

# Lambda used by pipeline to invalidate CloudFront cache after deploy.
module "lambda_invalidation" {
  source = "../../modules/lambda-invalidation"

  function_name   = "${var.project_name}-uat-cf-invalidator"
  distribution_id = module.cloudfront.distribution_id
  tags            = local.common_tags # Owner,Application,Environment,ManagedBy Tags
}

# Lambda used by pipeline Test stage to validate index.html in source artifact.
module "lambda_test" {
  source = "../../modules/lambda-test"

  function_name = "${var.project_name}-uat-test"
  tags          = local.common_tags # Owner,Application,Environment,ManagedBy Tags
}

# UAT pipeline is optional.
# Keep enable_pipeline=false until SNS subscription is confirmed and prod is ready.
module "codepipeline" {
  source = "../../modules/codepipeline"
  count  = var.enable_pipeline ? 1 : 0

  pipeline_name             = "${var.project_name}-uat-pipeline"
  connection_arn            = local.codestar_connection_arn
  github_owner              = var.github_owner
  github_repo               = var.github_repo
  github_branch             = var.github_branch
  app_bucket_name           = module.s3_site.bucket_name
  test_lambda_function_name = module.lambda_test.function_name
  test_lambda_function_arn  = module.lambda_test.function_arn
  lambda_function_name      = module.lambda_invalidation.function_name
  sns_topic_arn             = module.sns_notifications.topic_arn
  cloudfront_domain_name    = module.cloudfront.domain_name
  # Send success message after UAT deploy+invalidation, then ask approval to promote to prod.
  success_notification_after_uat_deploy = true
  enable_promotion_to_pipeline          = true
  promotion_pipeline_name               = "${var.project_name}-prod-pipeline"
  enable_manual_approval                = false
  tags                                  = local.common_tags # Owner,Application,Environment,ManagedBy Tags

  # Force infra prerequisites to exist before pipeline creation to reduce first-run race issues.
  depends_on = [
    module.sns_notifications,
    module.s3_site,
    module.cloudfront,
    module.lambda_invalidation,
    module.lambda_test
  ]
}
