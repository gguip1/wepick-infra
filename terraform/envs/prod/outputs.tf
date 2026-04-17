output "elastic_ip" {
  description = "앱 서버 Elastic IP"
  value       = module.ec2.elastic_ip
}

output "instance_id" {
  description = "EC2 인스턴스 ID (SSM 접속용)"
  value       = module.ec2.instance_id
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ssm_connect_command" {
  description = "Session Manager 접속 명령어"
  value       = "aws ssm start-session --target ${module.ec2.instance_id} --region ${var.aws_region}"
  sensitive   = true
}

output "artifacts_bucket_name" {
  description = "배포 파일 저장용 S3 버킷 이름 → GitHub Secrets AWS_S3_BUCKET_NAME에 등록"
  value       = aws_s3_bucket.artifacts.bucket
}

output "ecr_be_url" {
  description = "Backend ECR repository URL"
  value       = module.ecr.repository_urls["${var.project_name}-be"]
}

output "ecr_fe_url" {
  description = "Frontend ECR repository URL"
  value       = module.ecr.repository_urls["${var.project_name}-fe"]
}
