data "aws_ssm_parameter" "ubuntu2404_arm64_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.ubuntu2404_arm64_ami.value
}

resource "aws_instance" "this" {
  ami           = local.ami_id
  instance_type = var.instance_type

  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_id]
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true

  # key_name 생략 — SSH 대신 SSM Session Manager 사용
  key_name = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/scripts/userdata-app-server.sh", {
    project_name = var.project_name
    aws_region   = var.aws_region
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip" "this" {
  domain   = "vpc"
  instance = aws_instance.this.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-eip"
  }
}
