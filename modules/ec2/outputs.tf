output "instance_id" {
  description = "ID of the private EC2 test host."
  value       = aws_instance.this.id
}

output "role_arn" {
  description = "IAM role ARN for the EC2 test host, used for EKS access configuration."
  value       = aws_iam_role.this.arn
}

output "private_ip" {
  description = "Private IP address of the EC2 test host."
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "Security group for the EC2 test host."
  value       = aws_security_group.this.id
}
