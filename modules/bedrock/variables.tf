variable "project_name" {
  description = "Project name used for Bedrock agent resources."
  type        = string
}

variable "environment" {
  description = "Environment name for the deployment."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the Bedrock agent will be created."
  type        = string
}

variable "agent_name" {
  description = "Name of the Bedrock agent."
  type        = string
}

variable "agent_description" {
  description = "Description of the Bedrock agent."
  type        = string
  default     = "Workshop Bedrock agent"
}

variable "foundation_model" {
  description = "Foundation model ID to use for the Bedrock agent."
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "instruction" {
  description = "System instruction for the Bedrock agent."
  type        = string
}

variable "mcp_server_url" {
  description = "Private MCP endpoint that AgentCore or the runtime bridge should call. This should be the ALB-derived URL from the deployed runtime."
  type        = string
  default     = ""
}

variable "allowed_namespaces" {
  description = "Namespaces that are safe to inspect via the MCP tool layer."
  type        = list(string)
  default     = ["default", "kube-system", "prod", "staging"]
}

variable "idle_session_ttl_in_seconds" {
  description = "Idle session TTL in seconds."
  type        = number
  default     = 1800
}

variable "tags" {
  description = "Tags applied to Bedrock resources."
  type        = map(string)
  default     = {}
}
