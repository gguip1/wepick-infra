output "ec2_instance_profile_name" {
  description = "prod EC2 모듈에 전달할 instance profile 이름"
  value       = module.iam.instance_profile_name
}

output "ec2_role_name" {
  description = "prod env에서 추가 inline policy를 붙일 EC2 role 이름"
  value       = module.iam.role_name
}

output "ecr_be_url" {
  description = "Backend ECR repository URL"
  value       = module.ecr.repository_urls["${var.project_name}-be"]
}

output "ecr_fe_url" {
  description = "Frontend ECR repository URL"
  value       = module.ecr.repository_urls["${var.project_name}-fe"]
}

output "be_deploy_role_arn" {
  description = "wepick-be GitHub Actions가 assume할 role ARN — Secrets에 AWS_ROLE_ARN_DEPLOY로 등록"
  value       = aws_iam_role.be_deploy.arn
}

output "fe_deploy_role_arn" {
  description = "wepick-fe GitHub Actions가 assume할 role ARN — Secrets에 AWS_ROLE_ARN_DEPLOY로 등록"
  value       = aws_iam_role.fe_deploy.arn
}

output "infra_deploy_role_arn" {
  description = "wepick-infra GitHub Actions(Sync, Deploy)가 assume할 role ARN — Secrets AWS_ROLE_ARN으로 등록"
  value       = aws_iam_role.infra_deploy.arn
}
