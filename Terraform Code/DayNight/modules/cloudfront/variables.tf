variable "distribution_name" {
  description = "Name/comment applied to the distribution."
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name used as origin."
  type        = string
}

variable "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name used as origin domain."
  type        = string
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_All" # https://aws.amazon.com/cloudfront/pricing/#Price_Classes
  # PriceClass_100	North America, Europe, Israel	Cost(Lowest)
  # PriceClass_200	North America, Europe, Africa, Asia, Middle East	Cost(Moderate)
  # PriceClass_All	Global(All edge locations)	Cost(Highest)

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All", "None"], var.price_class)
    error_message = "price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All, None."
  }
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
