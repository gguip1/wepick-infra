output "repository_urls" {
  description = "{name => repository_url} 맵"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "{name => repository_arn} 맵"
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}
