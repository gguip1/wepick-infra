output "instance_id" {
  value = aws_instance.this.id
}

output "elastic_ip" {
  value = aws_eip.this.public_ip
}
