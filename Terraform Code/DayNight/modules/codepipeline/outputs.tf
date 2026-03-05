output "pipeline_name" {
  description = "CodePipeline name."
  value       = aws_codepipeline.this.name
}

output "pipeline_arn" {
  description = "CodePipeline ARN."
  value       = aws_codepipeline.this.arn
}

output "codepipeline_role_arn" {
  description = "IAM role ARN used by CodePipeline."
  value       = aws_iam_role.codepipeline_role.arn
}

output "artifact_bucket_name" {
  description = "S3 bucket name used by CodePipeline for both artifacts and deployment."
  value       = var.app_bucket_name
}
