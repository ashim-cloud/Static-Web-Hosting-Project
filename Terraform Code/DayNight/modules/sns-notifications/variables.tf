variable "topic_name" {
  description = "SNS topic name."
  type        = string
}

variable "email_subscriptions" {
  description = "List of email endpoints subscribed to this SNS topic."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
