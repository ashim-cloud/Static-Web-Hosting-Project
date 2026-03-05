# Package the Lambda source file into a zip for deployment.
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/index_test.zip"
  source_file = "${path.module}/lambda/index.py"
}

# IAM role assumed by the Lambda runtime.
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
# - reading CodePipeline artifact object from S3
# - reporting CodePipeline action result
# - writing logs to CloudWatch
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadArtifactObject"
        Effect = "Allow"
        Action = [
          # Lambda downloads the artifact ZIP using GetObject API.
          "s3:GetObject"
        ]
        # Bucket/object are provided by CodePipeline event at runtime.
        # Use wildcard object path to allow artifact retrieval.
        Resource = "arn:aws:s3:::*/*"
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

# Deploy Lambda function that validates index.html inside source artifact ZIP.
resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = var.tags
}
