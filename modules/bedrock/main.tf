data "aws_caller_identity" "current" {}

locals {
  tool_names = [
    "get_pods",
    "describe_pod",
    "get_events",
    "describe_deployment",
    "describe_service"
  ]

  effective_instruction = <<EOT
${var.instruction}

MCP tool bridge:
- MCP endpoint: ${var.mcp_server_url}
- Allowed namespaces: ${join(", ", var.allowed_namespaces)}
- Available tool functions: ${join(", ", local.tool_names)}

Safety rules:
- Only call MCP tools against the namespaces above.
- Do not run destructive Kubernetes actions or arbitrary shell commands.
- If the namespace is not listed, ask for clarification instead of guessing.
EOT
}

resource "aws_iam_role" "bedrock_agent_role" {
  name = "${var.project_name}-${var.environment}-bedrock-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "bedrock.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "bedrock-agent-model-access"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:foundation-model/*"
        ]
      }]
    })
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-bedrock-agent-role"
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_bedrockagent_agent" "this" {
  agent_name                  = var.agent_name
  agent_resource_role_arn     = aws_iam_role.bedrock_agent_role.arn
  description                 = var.agent_description
  foundation_model            = var.foundation_model
  instruction                 = local.effective_instruction
  idle_session_ttl_in_seconds = var.idle_session_ttl_in_seconds

  tags = merge(var.tags, {
    Name        = var.agent_name
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_bedrockagent_agent_alias" "default" {
  agent_alias_name = "default"
  agent_id         = aws_bedrockagent_agent.this.agent_id

  routing_configuration {
    agent_version = aws_bedrockagent_agent.this.agent_version
  }
}

resource "aws_bedrockagent_agent_action_group" "mcp_tools" {
  agent_id          = aws_bedrockagent_agent.this.agent_id
  agent_version     = aws_bedrockagent_agent.this.agent_version
  action_group_name = "mcp-tools"
  description       = "MCP-backed investigation and remediation tools exposed to the Bedrock agent."

  function_schema {
    member_functions {
      functions {
        name        = "get_pods"
        description = "List pods in an allowed Kubernetes namespace."

        parameters {
          map_block_key = "namespace"
          type          = "string"
          required      = true
          description   = "The Kubernetes namespace to inspect."
        }
      }

      functions {
        name        = "describe_pod"
        description = "Describe a single pod in the allowed namespace."

        parameters {
          map_block_key = "namespace"
          type          = "string"
          required      = true
          description   = "The namespace containing the pod."
        }

        parameters {
          map_block_key = "pod_name"
          type          = "string"
          required      = true
          description   = "The pod name to describe."
        }
      }

      functions {
        name        = "get_events"
        description = "Fetch recent Kubernetes events in a namespace."

        parameters {
          map_block_key = "namespace"
          type          = "string"
          required      = true
          description   = "The namespace to inspect."
        }
      }

      functions {
        name        = "describe_deployment"
        description = "Describe a deployment in the allowed namespace."

        parameters {
          map_block_key = "namespace"
          type          = "string"
          required      = true
          description   = "The deployment namespace."
        }

        parameters {
          map_block_key = "deployment_name"
          type          = "string"
          required      = true
          description   = "The deployment name."
        }
      }

      functions {
        name        = "describe_service"
        description = "Describe a Kubernetes service in the allowed namespace."

        parameters {
          map_block_key = "namespace"
          type          = "string"
          required      = true
          description   = "The namespace containing the service."
        }

        parameters {
          map_block_key = "service_name"
          type          = "string"
          required      = true
          description   = "The service name to inspect."
        }
      }
    }
  }

  prepare_agent = true
}
