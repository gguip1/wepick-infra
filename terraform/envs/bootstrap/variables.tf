variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" {
  type    = string
  default = "wepick"
}

variable "aws_account_id" {
  description = "AWS Account ID (버킷 이름 중복 방지용)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo (OIDC 인증 범위). 예: your-org/wepick-infra"
  type        = string
}
