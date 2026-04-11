output "elastic_ip" {
  description = "앱 서버 Elastic IP"
  value       = module.ec2.elastic_ip
}

output "instance_id" {
  description = "EC2 인스턴스 ID (SSM 접속용)"
  value       = module.ec2.instance_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ssm_connect_command" {
  description = "Session Manager 접속 명령어"
  value       = "aws ssm start-session --target ${module.ec2.instance_id} --region ${var.aws_region}"
}
