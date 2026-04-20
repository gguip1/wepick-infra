variable "aws_region" {
  description = "AWS region for region-scoped resources (ECR)"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project identifier used in resource names and tags"
  type        = string
  default     = "wepick"
}

variable "github_owner" {
  description = "GitHub owner (user or org) of wepick-be / wepick-fe repos"
  type        = string
  default     = "gguip1"
}
