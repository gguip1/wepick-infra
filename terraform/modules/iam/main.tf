data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.project_name}-${var.environment}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-role"
    Environment = var.environment
  }
}

# SSM Session Manager
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Parameter Store 읽기 (프로젝트 경로 한정)
data "aws_iam_policy_document" "parameter_store_read" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*",
    ]
  }
}

resource "aws_iam_policy" "parameter_store_read" {
  name   = "${var.project_name}-${var.environment}-parameter-store-read"
  policy = data.aws_iam_policy_document.parameter_store_read.json
}

resource "aws_iam_role_policy_attachment" "parameter_store_read" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.parameter_store_read.arn
}

# S3 읽기 (.env 배포 및 인증서 복원 경유용)
data "aws_iam_policy_document" "s3_read" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-deploy",
      "arn:aws:s3:::${var.project_name}-deploy/*",
    ]
  }
}

resource "aws_iam_policy" "s3_read" {
  name   = "${var.project_name}-${var.environment}-s3-read"
  policy = data.aws_iam_policy_document.s3_read.json
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.s3_read.arn
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.this.name
}
