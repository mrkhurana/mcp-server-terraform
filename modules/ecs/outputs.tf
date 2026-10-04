output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "internal_mcp_url" {
  description = "Private HTTP endpoint for the MCP service through the internal ALB."
  value       = "http://${aws_lb.this.dns_name}:${var.container_port}/mcp"
}

output "load_balancer_dns_name" {
  description = "Internal ALB DNS name, resolvable from the VPC."
  value       = aws_lb.this.dns_name
}

output "task_role_arn" {
  description = "ECS task role ARN registered with EKS for namespace-scoped access."
  value       = aws_iam_role.task.arn
}

output "task_execution_role_arn" {
  description = "ECS task execution role ARN."
  value       = aws_iam_role.execution.arn
}

output "task_security_group_id" {
  description = "Security group attached to ECS MCP tasks."
  value       = aws_security_group.tasks.id
}

output "alb_security_group_id" {
  description = "Security group attached to the internal ALB."
  value       = aws_security_group.alb.id
}

output "log_group_name" {
  description = "CloudWatch log group for MCP tasks."
  value       = aws_cloudwatch_log_group.this.name
}
