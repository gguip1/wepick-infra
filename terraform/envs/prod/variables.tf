variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" {
  type    = string
  default = "wepick"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "instance_type" {
  type    = string
  default = "t4g.small"
}

variable "ami_id" {
  description = "AMI ID. 비워두면 SSM에서 최신 Ubuntu 24.04 ARM64 자동 참조"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
