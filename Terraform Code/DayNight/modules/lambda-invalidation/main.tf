# Get current AWS account ID for resource ARNs in IAM policy.
data "aws_caller_identity" "current" {}

# Package the Lambda source file into a zip for deployment.
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/cloudfront_invalidator.zip"
  source_file = "${path.module}/lambda/cloudfront_invalidator.py"
}

# IAM role assumed by Lambda runtime.
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Inline IAM policy for:
# - creating CloudFront invalidations
# - reporting CodePipeline action result
# - writing logs to CloudWatch
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${var.distribution_id}"
      },
      {
        Sid    = "CodePipelineResultReporting"
        Effect = "Allow"
        Action = [
          "codepipeline:PutJobFailureResult",
          "codepipeline:PutJobSuccessResult"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Deploy Lambda function that invalidates CloudFront cache paths.
resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "cloudfront_invalidator.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      # Distribution ID is passed as environment variable to the function.
      DISTRIBUTION_ID = var.distribution_id
    }
  }

  tags = var.tags
}

