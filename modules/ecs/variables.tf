variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region for ECS and IAM resource ARNs."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing the ECS cluster, ALB, and tasks."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR allowed to access the internal ALB."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ECS tasks."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB."
  type        = list(string)
}

variable "allowed_public_cidrs" {
  description = "CIDR blocks allowed to reach the public ALB."
  type        = list(string)
  default     = []
}

variable "s3_prefix_list_id" {
  description = "S3 gateway endpoint prefix list used by private ECR image pulls."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster accessed by the ECS task role."
  type        = string
}

variable "container_image" {
  description = "Existing private ECR image URI. This module does not create an ECR repository."
  type        = string
}

variable "container_image_repository_arn" {
  description = "ARN of the existing ECR repository containing container_image, used to scope image-pull permissions."
  type        = string
}

variable "container_port" {
  description = "MCP server listening port."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired ECS service task count."
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "HTTP health path exposed by the MCP container for ALB target health checks."
  type        = string
  default     = "/mcp"
}

variable "mcp_kubernetes_namespace" {
  description = "Namespace allowlist passed to the MCP container and authorized by EKS access policy."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention period."
  type        = number
}

variable "task_execution_role_name" {
  description = "Optional ECS task execution role name override."
  type        = string
  default     = null
}

variable "task_role_name" {
  description = "Optional ECS MCP task role name override."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to ECS resources."
  type        = map(string)
  default     = {}
}
