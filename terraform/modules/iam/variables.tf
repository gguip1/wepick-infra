variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "artifacts_bucket_name" {
  type        = string
  description = "docker-compose, nginx config 저장용 S3 버킷 이름"
}
