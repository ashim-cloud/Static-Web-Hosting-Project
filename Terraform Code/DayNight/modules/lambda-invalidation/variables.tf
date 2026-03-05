variable "function_name" {
  description = "Lambda function name."
  type        = string
}

variable "distribution_id" {
  description = "CloudFront distribution ID to invalidate."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
