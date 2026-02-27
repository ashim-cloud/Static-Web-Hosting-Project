variable "pipeline_name" {
  description = "CodePipeline name."
  type        = string
}

variable "connection_arn" {
  description = "CodeStar connection ARN for GitHub."
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner/user."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to deploy."
  type        = string
}

variable "app_bucket_name" {
  description = "Destination S3 bucket for static app deployment."
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function invoked after deployment for CloudFront invalidation."
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN used for notifications."
  type        = string
}

variable "cloudfront_domain_name" {
  description = "CloudFront domain name included in pipeline notifications."
  type        = string
}

variable "enable_manual_approval" {
  description = "Enable manual approval stage. Intended for production."
  type        = bool
  default     = false
}

variable "pipeline_type" {
  description = "Pipeline type (V1 or V2)."
  type        = string
  default     = "V2"
}

variable "source_detect_changes" {
  description = "Enable automatic executions when source changes are detected."
  type        = bool
  default     = true
}

variable "success_notification_after_uat_deploy" {
  description = "Send success notification after Deploy+Invalidate action success instead of full pipeline completion."
  type        = bool
  default     = false
}

variable "enable_promotion_to_pipeline" {
  description = "Add manual approval and invoke stage to trigger another pipeline."
  type        = bool
  default     = false
}

variable "promotion_pipeline_name" {
  description = "Downstream pipeline name triggered after approval."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_promotion_to_pipeline || length(trimspace(var.promotion_pipeline_name)) > 0
    error_message = "promotion_pipeline_name must be set when enable_promotion_to_pipeline is true."
  }
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
