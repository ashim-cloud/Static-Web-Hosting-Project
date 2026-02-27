# Useful values returned after `terraform apply` in UAT.

# Bucket Name
output "uat_s3_bucket_name" {
  description = "UAT static site S3 bucket name."
  value       = module.s3_site.bucket_name
}

# CloudFront Distribution Name
output "uat_cloudfront_domain_name" {
  description = "UAT CloudFront domain name."
  value       = module.cloudfront.domain_name
}

# UAT Pipeline Name
output "uat_pipeline_name" {
  description = "UAT CodePipeline name."
  # Pipeline output is null when enable_pipeline=false.
  value       = var.enable_pipeline ? module.codepipeline[0].pipeline_name : null
}

# SNS Topic Name
output "uat_sns_topic_name" {
  description = "UAT SNS topic name used for pipeline notifications."
  value       = module.sns_notifications.topic_name
}

output "uat_sns_topic_arn" {
  description = "UAT SNS topic ARN used for pipeline notifications."
  value       = module.sns_notifications.topic_arn
}

# Email Address
output "uat_sns_subscription_emails" {
  description = "Email addresses configured for UAT SNS subscriptions."
  value       = module.sns_notifications.email_subscription_endpoints
}

output "uat_sns_subscription_arns" {
  description = "SNS subscription ARNs or pending confirmation identifiers."
  value       = module.sns_notifications.email_subscription_arns
}
