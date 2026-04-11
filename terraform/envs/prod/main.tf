terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 추후 S3 backend 전환 권장
  # backend "s3" {
  #   bucket = "wepick-tfstate"
  #   key    = "envs/prod/terraform.tfstate"
  #   region = "ap-northeast-2"
  # }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  cidr_block         = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
}

module "security_group" {
  source = "../../modules/security_group"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

module "ec2" {
  source = "../../modules/ec2"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  instance_type         = var.instance_type
  ami_id                = var.ami_id
  subnet_id             = module.vpc.public_subnet_id
  sg_id                 = module.security_group.sg_id
  instance_profile_name = module.iam.instance_profile_name
}
