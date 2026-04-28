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
    key          = "envs/shared/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project    = var.project_name
      managed_by = "terraform"
      layer      = "global"
    }
  }
}

data "aws_caller_identity" "current" {}

# bootstrap state에서 OIDC provider ARN 받음 (로컬 state)
data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "../bootstrap/terraform.tfstate"
  }
}

locals {
  oidc_provider_arn = data.terraform_remote_state.bootstrap.outputs.github_oidc_provider_arn
  artifacts_bucket  = "${var.project_name}-artifacts-${data.aws_caller_identity.current.account_id}"
  ecr_be_repo_name  = "${var.project_name}-be"
  ecr_fe_repo_name  = "${var.project_name}-fe"
}

# ─────────────────────────────────────────────
# IAM (EC2 instance role) + ECR (repos)
# ─────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  project_name          = var.project_name
  environment           = "prod"
  aws_region            = var.aws_region
  artifacts_bucket_name = local.artifacts_bucket
}

module "ecr" {
  source           = "../../modules/ecr"
  repository_names = [local.ecr_be_repo_name, local.ecr_fe_repo_name]
}

# ─────────────────────────────────────────────
# BE Deploy OIDC Role (wepick-be repo의 main 브랜치 한정)
# ─────────────────────────────────────────────
resource "aws_iam_role" "be_deploy" {
  name = "${var.project_name}-be-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.project_name}-be:ref:refs/heads/main"
        }
      }
    }]
  })
}

data "aws_iam_policy_document" "be_ecr_push" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushBE"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [module.ecr.repository_arns[local.ecr_be_repo_name]]
  }
}

resource "aws_iam_role_policy" "be_ecr_push" {
  name   = "${var.project_name}-be-ecr-push"
  role   = aws_iam_role.be_deploy.id
  policy = data.aws_iam_policy_document.be_ecr_push.json
}

data "aws_iam_policy_document" "be_prod_deploy" {
  statement {
    sid = "SsmParameterRead"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/instance_id",
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/artifacts_bucket",
    ]
  }

  statement {
    sid = "SsmImageTagWrite"
    actions = [
      "ssm:PutParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/be_image_tag",
    ]
  }

  statement {
    sid     = "SsmSendCommandDocument"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
    ]
  }

  statement {
    sid     = "SsmSendCommandInstance"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:*:instance/*",
    ]
  }

  statement {
    sid = "SsmCommandResult"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:DescribeInstanceInformation",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "be_prod_deploy" {
  name   = "${var.project_name}-be-prod-deploy"
  role   = aws_iam_role.be_deploy.id
  policy = data.aws_iam_policy_document.be_prod_deploy.json
}

# ─────────────────────────────────────────────
# FE Deploy OIDC Role
# ─────────────────────────────────────────────
resource "aws_iam_role" "fe_deploy" {
  name = "${var.project_name}-fe-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.project_name}-fe:ref:refs/heads/main"
        }
      }
    }]
  })
}

data "aws_iam_policy_document" "fe_ecr_push" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushFE"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [module.ecr.repository_arns[local.ecr_fe_repo_name]]
  }
}

resource "aws_iam_role_policy" "fe_ecr_push" {
  name   = "${var.project_name}-fe-ecr-push"
  role   = aws_iam_role.fe_deploy.id
  policy = data.aws_iam_policy_document.fe_ecr_push.json
}

data "aws_iam_policy_document" "fe_prod_deploy" {
  statement {
    sid = "SsmParameterRead"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/instance_id",
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/artifacts_bucket",
    ]
  }

  statement {
    sid = "SsmImageTagWrite"
    actions = [
      "ssm:PutParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/fe_image_tag",
    ]
  }

  statement {
    sid     = "SsmSendCommandDocument"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
    ]
  }

  statement {
    sid     = "SsmSendCommandInstance"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:*:instance/*",
    ]
  }

  statement {
    sid = "SsmCommandResult"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:DescribeInstanceInformation",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "fe_prod_deploy" {
  name   = "${var.project_name}-fe-prod-deploy"
  role   = aws_iam_role.fe_deploy.id
  policy = data.aws_iam_policy_document.fe_prod_deploy.json
}

# ─────────────────────────────────────────────
# wepick-infra Deploy OIDC Role (Sync + Deploy 워크플로용)
# ─────────────────────────────────────────────
resource "aws_iam_role" "infra_deploy" {
  name = "${var.project_name}-infra-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.project_name}-infra:ref:refs/heads/main"
        }
      }
    }]
  })
}

data "aws_iam_policy_document" "infra_deploy" {
  # S3 artifacts (compose-sync용)
  statement {
    sid = "S3ArtifactsRW"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${local.artifacts_bucket}",
      "arn:aws:s3:::${local.artifacts_bucket}/*",
    ]
  }

  # SSM Parameter Store (deploy.yml이 image_tag 업데이트, instance_id 조회)
  statement {
    sid = "SsmParameter"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:PutParameter",
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"]
  }

  # SSM SendCommand (deploy.yml이 EC2에 명령 실행)
  statement {
    sid     = "SsmSendCommandDocument"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
    ]
  }

  statement {
    sid     = "SsmSendCommandInstance"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:*:instance/*",
    ]
  }

  statement {
    sid = "SsmCommandResult"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:DescribeInstanceInformation",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "infra_deploy" {
  name   = "${var.project_name}-infra-deploy"
  role   = aws_iam_role.infra_deploy.id
  policy = data.aws_iam_policy_document.infra_deploy.json
}
