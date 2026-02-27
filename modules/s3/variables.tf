variable "bucket_name" {
  description = "Base name for the website bucket. Final bucket name is created using this as prefix for uniqueness."
  type        = string
}

variable "force_destroy" {
  description = "Allow bucket deletion even when it contains objects."
  type        = bool
  default     = false
}

variable "enable_cloudfront_read_access" {
  description = "Allow CloudFront service to read objects from this bucket."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
