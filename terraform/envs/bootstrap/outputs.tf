output "tfstate_bucket_name" {
  description = "tfstate 저장용 S3 버킷 이름"
  value       = aws_s3_bucket.tfstate.bucket
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC Provider ARN — global의 BE/FE deploy role이 의존"
  value       = aws_iam_openid_connect_provider.github.arn
}
