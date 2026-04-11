variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t4g.small"
}

variable "ami_id" {
  description = "AMI ID. 비워두면 SSM에서 최신 AL2023 ARM64 자동 참조"
  type        = string
  default     = ""
}

variable "subnet_id" {
  type = string
}

variable "sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "key_name" {
  description = "EC2 Key Pair (SSM 사용 시 불필요)"
  type        = string
  default     = ""
}
