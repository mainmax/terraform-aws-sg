output "id" {
  description = "Security Group ID"
  value       = aws_security_group.this.id
}

output "name" {
  description = "Security Group Name"
  value       = aws_security_group.this.name
}

output "arn" {
  description = "Security Group ARN"
  value       = aws_security_group.this.arn
}

output "vpc_id" {
  description = "Security Group VPC ID"
  value = aws_security_group.this.vpc_id
}