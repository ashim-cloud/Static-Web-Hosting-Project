# Useful values returned after `terraform apply` in production.

#Bucket Name
output "prod_s3_bucket_name" {
  description = "Production static site S3 bucket name."
  value       = module.s3_site.bucket_name
}

#CloudFront Domain Name [CName = Conical Name]
output "prod_cloudfront_domain_name" {
  description = "Production CloudFront domain name."
  value       = module.cloudfront.domain_name
}

# CodePipeline Name
output "prod_pipeline_name" {
  description = "Production CodePipeline name."
  value       = module.codepipeline.pipeline_name
}
