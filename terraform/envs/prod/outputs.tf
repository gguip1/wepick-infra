output "elastic_ip" {
  description = "앱 서버 Elastic IP"
  value       = module.ec2.elastic_ip
}

output "operator_managed_ssm_parameters" {
  description = "Terraform created these with placeholder values. Set actual values before app deploy."
  value = [
    "aws ssm put-parameter --name '/${var.project_name}/mysql_password' --value '<실제값>' --type SecureString --overwrite",
    "aws ssm put-parameter --name '/${var.project_name}/mysql_root_password' --value '<실제값>' --type SecureString --overwrite",
  ]
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

output "images_bucket_name" {
  description = "사용자 이미지 업로드용 private S3 버킷 이름"
  value       = aws_s3_bucket.images.bucket
}

output "images_cloudfront_domain" {
  description = "사용자 이미지 조회용 CloudFront 기본 도메인"
  value       = aws_cloudfront_distribution.images.domain_name
}
