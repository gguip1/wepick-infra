variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project identifier used in resource names and tags"
  type        = string
  default     = "wepick"
}

variable "environment" {
  description = "Deployment environment (prod/dev/staging)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "dev", "staging"], var.environment)
    error_message = "environment must be one of: prod, dev, staging."
  }
}

variable "instance_type" {
  description = "EC2 instance type (ARM64 recommended for cost)"
  type        = string
  default     = "t4g.small"
}

variable "ami_id" {
  description = "AMI ID. 비워두면 SSM에서 최신 Ubuntu 24.04 ARM64 자동 참조"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block (must be within vpc_cidr)"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid CIDR block."
  }
}

variable "domain_name" {
  description = "Public domain name served by nginx (e.g., wepick.example.com)"
  type        = string
}
