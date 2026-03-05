# Reusable origin ID for the S3 origin in this distribution.
locals {
  origin_id = "s3-${var.bucket_name}"
}

# Create Origin Access Control so CloudFront signs requests to S3.
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.distribution_name}-oac"
  description                       = "OAC for ${var.distribution_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Create CloudFront distribution in front of the S3 bucket.
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = var.distribution_name
  default_root_object = "index.html"
  price_class         = var.price_class

  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  # Main cache behavior for website traffic.
  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
  }

  # No geo restrictions.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Use default CloudFront certificate (*.cloudfront.net).
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # SPA-friendly error rewrites to index.html.
  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  tags = var.tags
}
