# Input variables for the production environment.

variable "aws_region" {
  description = "Primary AWS region for production resources."
  type        = string
  default     = "ap-southeast-1" # Singapore
}

variable "project_name" {
  description = "Project name prefix used for resource naming."
  type        = string
}

variable "github_owner" {
  description = "GitHub owner/user."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_branch" {
  description = "GitHub branch name for production deployments."
  type        = string
  default     = "main"
}

variable "tags" {
  description = "Additional tags for production resources."
  type        = map(string)
  default     = {}

  validation {
    # These keys must always exist and have non-empty values.
    condition = alltrue([
      for key in ["Application", "Owner", "Environment", "ManagedBy"] :
      contains(keys(var.tags), key) && length(trimspace(var.tags[key])) > 0
    ])
    error_message = "tags must include non-empty values for Application, Owner, Environment, and ManagedBy."
  }
}

