output "agent_id" {
  description = "Bedrock agent ID."
  value       = aws_bedrockagent_agent.this.id
}

output "agent_arn" {
  description = "Bedrock agent ARN."
  value       = aws_bedrockagent_agent.this.agent_arn
}

output "agent_alias_id" {
  description = "Bedrock agent alias ID."
  value       = aws_bedrockagent_agent_alias.default.agent_alias_id
}

output "action_group_id" {
  description = "Bedrock agent action group ID for MCP-backed tool functionality."
  value       = aws_bedrockagent_agent_action_group.mcp_tools.id
}

output "agent_role_arn" {
  description = "IAM role ARN used by the Bedrock agent."
  value       = aws_iam_role.bedrock_agent_role.arn
}
