variable "project_name" {
  type = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Amazon EKS Kubernetes version."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the cluster and managed node group."
  type        = list(string)
}

variable "mcp_task_role_arn" {
  description = "IAM role ARN for the ECS MCP task's read-only Kubernetes access."
  type        = string
}

variable "mcp_security_group_id" {
  description = "ECS task security group allowed to reach the private Kubernetes API endpoint."
  type        = string
}

variable "mcp_namespace" {
  description = "Namespace scope for the EKS managed read-only policy."
  type        = string
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access the EKS public endpoint."
  type        = list(string)
  default     = []
}

variable "admin_principal_arn" {
  description = "Optional IAM principal to grant cluster-admin access for the workshop. Defaults to the current AWS root principal when empty."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Retention period for EKS control-plane logs."
  type        = number
}

variable "tags" {
  type    = map(string)
  default = {}
}
