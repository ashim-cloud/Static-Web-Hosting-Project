output "topic_arn" {
  description = "SNS topic ARN."
  value       = aws_sns_topic.this.arn
}

output "topic_name" {
  description = "SNS topic name."
  value       = aws_sns_topic.this.name
}

output "email_subscription_endpoints" {
  description = "Email endpoints configured for SNS subscriptions."
  value       = var.email_subscriptions
}

output "email_subscription_arns" {
  description = "SNS subscription ARNs (or pending confirmation identifiers)."
  value       = [for sub in aws_sns_topic_subscription.email : sub.arn]
}
