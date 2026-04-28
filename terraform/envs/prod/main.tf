terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "wepick-tfstate-149465616382"
    key          = "envs/prod/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project     = var.project_name
      environment = var.environment
      managed_by  = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

# shared state에서 IAM·ECR 등 계정 공유 자원 참조
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "wepick-tfstate-149465616382"
    key    = "envs/shared/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 배포 파일 저장용 S3 버킷 (docker-compose, nginx config)
locals {
  ssm_string_parameters = {
    aws_region          = var.aws_region
    mysql_host          = var.mysql_host
    mysql_port          = var.mysql_port
    mysql_database      = var.mysql_database
    mysql_user          = var.mysql_user
    be_image            = data.terraform_remote_state.shared.outputs.ecr_be_url
    fe_image            = data.terraform_remote_state.shared.outputs.ecr_fe_url
    domain_name         = var.domain_name
    artifacts_bucket    = aws_s3_bucket.artifacts.bucket
    instance_id         = module.ec2.instance_id
    s3_bucket_name      = aws_s3_bucket.images.bucket
    cloud_aws_s3_domain = "https://${aws_cloudfront_distribution.images.domain_name}/"
  }

  ssm_image_tag_parameters = {
    be_image_tag = var.initial_image_tag
    fe_image_tag = var.initial_image_tag
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-artifacts"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "images" {
  bucket = "${var.project_name}-${var.environment}-images-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-${var.environment}-images"
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT"]
    allowed_origins = var.image_cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_cloudfront_origin_access_control" "images" {
  name                              = "${var.project_name}-${var.environment}-images-oac"
  description                       = "OAC for ${var.project_name} ${var.environment} images bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "images" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name}-${var.environment} images"
  price_class     = "PriceClass_200"

  origin {
    domain_name              = aws_s3_bucket.images.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.images.id
    origin_id                = "images-s3"
  }

  default_cache_behavior {
    target_origin_id       = "images-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-images"
  }
}

data "aws_iam_policy_document" "images_bucket" {
  statement {
    sid = "AllowCloudFrontRead"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.images.arn}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.images.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "images" {
  bucket = aws_s3_bucket.images.id
  policy = data.aws_iam_policy_document.images_bucket.json
}

data "aws_iam_policy_document" "ec2_images" {
  statement {
    sid = "ImagesObjectWrite"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.images.arn}/*",
    ]
  }

  statement {
    sid = "ImagesBucketRead"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.images.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ec2_images" {
  name   = "${var.project_name}-${var.environment}-images"
  role   = data.terraform_remote_state.shared.outputs.ec2_role_name
  policy = data.aws_iam_policy_document.ec2_images.json
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

module "ec2" {
  source = "../../modules/ec2"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  instance_type         = var.instance_type
  ami_id                = var.ami_id
  subnet_id             = module.vpc.public_subnet_id
  sg_id                 = module.security_group.sg_id
  instance_profile_name = data.terraform_remote_state.shared.outputs.ec2_instance_profile_name
}

resource "aws_ssm_parameter" "string" {
  for_each = local.ssm_string_parameters

  name      = "/${var.project_name}/${each.key}"
  type      = "String"
  value     = each.value
  overwrite = true
}

resource "aws_ssm_parameter" "image_tag" {
  for_each = local.ssm_image_tag_parameters

  name      = "/${var.project_name}/${each.key}"
  type      = "String"
  value     = each.value
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}
