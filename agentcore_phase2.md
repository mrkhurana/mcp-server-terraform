# Phase 2: Bedrock + AgentCore foundation

This repo keeps the current Phase 1 runtime infrastructure intact and adds the next phase foundation for an AWS Bedrock-powered workflow.

## Included in this repo

- AgentCore-first runtime path behind the private internal ALB
- MCP service and Kubernetes investigation toolchain
- Optional Bedrock module scaffold under `modules/bedrock` for accounts/regions where Bedrock Agents is available
- IAM role and outputs for the Bedrock module when enabled

## Current status

The Bedrock agent is intentionally disabled by default because AWS Bedrock Agents is in maintenance mode for new account creation in the current account/region. The repository therefore uses AgentCore as the primary Phase 2 integration path and keeps the Bedrock module available as an optional future activation.

## Not included yet

- AgentCore Runtime
- AgentCore Gateway
- VPC Lattice
- public HTTPS / custom domain
- Bedrock Knowledge Base chaining
- multi-agent orchestration

## Recommended next AgentCore step

Once AWS AgentCore resources are available for your account/region, attach the runtime behind the private internal ALB and use the MCP toolchain as the operational layer behind the AgentCore entry point.

The repo now exposes the Bedrock-side MCP contract through the following values:

- `mcp_server_url` variable: the private MCP endpoint that the agent should target
- `mcp_allowed_namespaces`: safe, restricted namespaces for Kubernetes inspection
- `bedrock_agent` outputs: agent alias and action group metadata for downstream runtime wiring

The intended flow is:

```text
User / client
  ↓
AgentCore Gateway
  ↓
Internal ALB
  ↓
ECS MCP server
  ↓
EKS / Kubernetes
```

with the Bedrock agent acting as the model layer and reasoning engine.
