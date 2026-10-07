variable "project_name" {
  description = "Base name used for AWS resources."
  type        = string
  default     = "mcp-server"
}

variable "environment" {
  description = "Environment name such as dev, staging, or prod."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region where resources are deployed."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS shared profile to use when running Terraform locally."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability zones used for private subnets. Empty selects the first two available zones in the region."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks for EKS nodes and ECS tasks."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs are required for the EKS cluster."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks used for the internet-facing ALB."
  type        = list(string)
  default     = ["10.20.21.0/24", "10.20.22.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs are required for the public ALB."
  }
}

variable "public_allowed_cidrs" {
  description = "CIDR blocks permitted to reach the public MCP ALB and the EKS public endpoint. Set this in terraform.tfvars."
  type        = list(string)
  default     = []
}

variable "enable_vpc_endpoints" {
  description = "Create ECR, EC2, CloudWatch Logs, and S3 endpoints instead of using a NAT gateway."
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "EKS cluster name. Defaults to project-environment when empty."
  type        = string
  default     = ""
}

variable "eks_kubernetes_version" {
  description = "Kubernetes minor version for EKS. Keep this aligned with a version currently supported by Amazon EKS."
  type        = string
  default     = "1.36"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired EKS managed node group size."
  type        = number
  default     = 1
}

variable "eks_node_min_size" {
  description = "Minimum EKS managed node group size."
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum EKS managed node group size."
  type        = number
  default     = 2
}

variable "mcp_kubernetes_namespace" {
  description = "Kubernetes namespace where the future MCP task role receives read-only EKS access."
  type        = string
  default     = "application"
}

variable "mcp_workload_ecr_repositories" {
  description = "ECR repositories (names) whose images the MCP server may deploy with set_image and list with list_image_tags."
  type        = list(string)
  default     = ["nginx"]
}

variable "mcp_allowed_deployments" {
  description = "Deployments the MCP server may change. Empty allows every deployment in the namespace."
  type        = list(string)
  default     = ["nginx"]
}

variable "mcp_enable_remediation" {
  description = "Set false to make every state-changing MCP tool refuse (read-only mode)."
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Private MCP security-group port reserved for the future ECS task."
  type        = number
  default     = 8080
}

variable "container_image" {
  description = "Existing private ECR image URI for the MCP server; Terraform does not create or push the repository/image."
  type        = string
}

variable "container_image_repository_arn" {
  description = "ARN of the existing ECR repository containing container_image for least-privilege task image pulls."
  type        = string
}

variable "ecs_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "ecs_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of ECS MCP tasks."
  type        = number
  default     = 1
}

variable "mcp_health_check_path" {
  description = "HTTP health check path implemented by the supplied MCP image."
  type        = string
  default     = "/health"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs."
  type        = number
  default     = 7
}

variable "task_execution_role_name" {
  description = "Name for the ECS task execution role."
  type        = string
  default     = null
}

variable "task_role_name" {
  description = "Name for the future ECS MCP task role."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
