output "vpc_id" {
  description = "VPC ID created for the platform."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes and future ECS tasks."
  value       = module.vpc.private_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN associated with the EKS namespace-scoped view policy."
  value       = module.ecs.task_role_arn
}

output "ecs_task_execution_role_arn" {
  description = "ECS execution role ARN used for image pulls and CloudWatch log delivery."
  value       = module.ecs.task_execution_role_arn
}

output "eks_cluster_role_arn" {
  description = "EKS control-plane IAM role ARN."
  value       = module.eks.cluster_role_arn
}

output "eks_node_role_arn" {
  description = "EKS managed node group IAM role ARN."
  value       = module.eks.node_role_arn
}

output "ecs_log_group_name" {
  description = "CloudWatch log group for ECS MCP task logs."
  value       = module.ecs.log_group_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}

output "internal_mcp_url" {
  description = "Public MCP HTTP endpoint exposed through the internet-facing ALB."
  value       = module.ecs.internal_mcp_url
}

output "load_balancer_dns_name" {
  description = "ALB DNS name for the public MCP endpoint."
  value       = module.ecs.load_balancer_dns_name
}

output "eks_log_group_name" {
  description = "CloudWatch log group for EKS control plane logs."
  value       = module.eks.log_group_name
}
