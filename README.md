# EKS and ECS MCP Infrastructure

This Terraform repository provisions the AWS infrastructure for the AI Ops MCP workshop:

- a custom Python MCP server running on ECS Fargate, behind an ALB on HTTP port 8080
- an EKS cluster whose `application` namespace runs an nginx workload the MCP server can investigate and remediate

The ECS service uses an image from an **existing private ECR repository**, created and pushed by `mcp-server-deployments`. This repository doesn't create the ECR repository or build images.

## Deployment order

This repository is step 2 of 3:

```bash
# 1. Build and push the MCP server image to ECR
cd mcp-server-deployments && ./deploy.sh v0.1.0

# 2. Create the AWS infrastructure and the nginx workload (this repository)
cd ../mcp-server-terraform && ./deploy.sh

# 3. Verify the MCP server and connect Claude Desktop
cd ../mcp-client && ./deploy.sh
```

## Architecture

```text
Claude Desktop (your laptop, IP in public_allowed_cidrs)
   │ HTTP :8080 /mcp, Authorization: Bearer <token from SSM>
   ▼
ALB (internet-facing, public subnets; SG allows 8080 only from public_allowed_cidrs)
   ▼
ECS Fargate MCP task (private subnet, no public IP)
   │ HTTPS 443 → private EKS API endpoint
   │ identity: ECS task IAM role (eks:DescribeCluster only)
   ▼
EKS: Access Entry → groups aiops-mcp-investigate / aiops-mcp-remediate → RoleBindings → Roles in "application"
   ▼
namespace "application" → nginx Deployment + ClusterIP Service
```

```text
VPC 10.20.0.0/16
├── Public subnets (2 AZs) + Internet Gateway: used only by the ALB
├── Private subnets (2 AZs), no NAT Gateway, no default route
│   ├── ECS Fargate MCP tasks
│   ├── EKS control-plane ENIs and EKS compute
│   └── VPC endpoints: ecr.api, ecr.dkr, ec2, eks, logs, ssm, ssmmessages, ec2messages (interface); s3 (gateway)
└── CloudWatch log groups: /ecs/<project>-<environment>, /aws/eks/<cluster>/cluster
```

The Terraform output `internal_mcp_url` is `http://<alb-dns>:8080/mcp`. The name is historical: the ALB is internet-facing and reachable only from the CIDRs in `public_allowed_cidrs`.

The EKS API endpoint is private, plus a public endpoint restricted to `public_allowed_cidrs` so `deploy.sh` can run `kubectl` from your laptop.

## Modules

| Module | Wired in `main.tf` | Contents |
|---|---|---|
| `modules/vpc` | yes | VPC, public and private subnets, Internet Gateway, route tables, VPC endpoints, endpoint security group |
| `modules/ecs` | yes | ECS cluster, Fargate task definition and service, ALB, listener, target group, task and execution roles, security groups, CloudWatch log group |
| `modules/eks` | yes | EKS cluster, control-plane logs, access entries, EKS Fargate profile for `application` and `kube-system` |
| `modules/ec2` | no | Private SSM test host (unused) |
| `modules/bedrock` | no | Bedrock agent scaffold (unused, see `agentcore_phase2.md`) |

## EKS access for the MCP server

```text
ECS task IAM role
   → EKS Access Entry (kubernetes_groups: aiops-mcp-investigate, aiops-mcp-remediate)
   → RoleBindings in "application"
   → Roles in kubernetes/rbac.yaml
```

- The ECS task role has only `eks:DescribeCluster` on this cluster, plus `ecr:DescribeRepositories` and `ecr:DescribeImages` on the workload repositories (`mcp_workload_ecr_repositories`). No kubeconfig or Kubernetes token is stored anywhere.
- No EKS access policy is associated with the role, so its Kubernetes permissions are exactly what `kubernetes/rbac.yaml` grants, and only in `application`:
  - **investigate:** get and list on pods, pods/log, events, services, endpoints, deployments and replicasets, plus get on services/proxy
  - **remediate:** delete pods, get and patch deployments/scale, patch deployments
- Nothing on secrets, nothing cluster-wide, and no `cluster-admin`. Application-level rules (allowed deployments, replica, CPU and memory bounds, allowed image repositories) are enforced by the MCP server on top.

## MCP endpoint authentication

Terraform generates a random bearer token, stores it as the SSM SecureString parameter in the `mcp_auth_token_parameter` output, and ECS injects it into the container as `MCP_AUTH_TOKEN`. Requests to `/mcp` without `Authorization: Bearer <token>` get 401, while `/health` stays open for the ALB. `mcp-client/deploy.sh` reads the token with `aws ssm get-parameter` and writes it into the Claude Desktop config.

The token is also stored in the Terraform state (S3, encrypted). To rotate it:

```bash
terraform apply -replace=module.ecs.random_password.mcp_auth_token
```

Then re-run `mcp-client/deploy.sh`.

## Kubernetes manifests

Applied by `deploy.sh` with `kubectl` after `terraform apply`:

| File | Contents |
|---|---|
| `kubernetes/namespace.yaml` | `application` namespace |
| `kubernetes/rbac.yaml` | MCP investigate and remediate Roles and RoleBindings |
| `kubernetes/nginx.yaml` | nginx Deployment (1 replica, readiness probe on `/`, image from private ECR) and ClusterIP Service. `deploy.sh` replaces `<ECR_REGISTRY>` with the registry of `container_image` |
| `kubernetes/demo/break.sh` | Fault injection for the live demo (see below) |

## Live demo faults

`kubernetes/demo/break.sh` breaks nginx in one of these ways. The agent is never told which one, so it has to find out from the cluster.

| Fault | What breaks | Tool that fixes it |
|---|---|---|
| `./break.sh scale-zero` | 0 replicas, so the Service has no endpoints | `scale_deployment` |
| `./break.sh readiness` | Pod Running but NotReady, because the readiness probe gets 403 | `restart_pod` |
| `./break.sh bad-image` | Rollout to a tag that doesn't exist (ImagePullBackOff) | `rollback_deployment` |
| `./break.sh oom` | 4Mi memory limit, so the container is OOMKilled | `update_resources` |
| `./break.sh reset` | Puts nginx back to `nginx.yaml` | none |

By default `bad-image` and `oom` leave the old pod serving, because a rolling update only replaces it once the new pod is ready. Add `--kill` (for example `./break.sh oom --kill`) to switch the Deployment to the `Recreate` strategy first, so the existing pod is stopped and nginx is really down until the agent fixes it. `--kill` makes no difference to `scale-zero` and is ignored by `readiness`, where a fresh pod would undo the fault. `./break.sh reset` restores the rolling update strategy.

Several faults can be injected in one call, in any order, for example `./break.sh bad-image scale-zero` or `./break.sh bad-image oom --kill`. They are applied as `readiness`, then `bad-image`/`oom`, then `scale-zero`. `bad-image` and `oom` together are one change (one revision), so a single `rollback_deployment` undoes both. The script refuses combinations where one fault would undo another (`readiness` with `scale-zero`, or `readiness` with `--kill` and `bad-image`/`oom`), and `reset` must be used on its own.

| Combination | What the agent has to work out |
|---|---|
| `bad-image scale-zero` | Scaling up isn't enough: the new pod can't pull its image, so it also has to roll back |
| `readiness oom` | Two root causes: the old pod is NotReady and the new one is OOMKilled |
| `bad-image oom --kill` | A full outage that one rollback fixes |

## Known gaps

- **No managed node group.** EKS compute is an EKS Fargate profile. The `eks_node_*` variables in `terraform.tfvars` are declared but not passed to the EKS module.
- **`authentication_mode` is `API_AND_CONFIG_MAP`.** Nothing uses `aws-auth`, but `API` alone would rule it out entirely. Switching is one-way.

## Image prerequisite

Set `container_image` and `container_image_repository_arn` in `terraform.tfvars` to the image pushed by `mcp-server-deployments`. The image must listen on `0.0.0.0:8080`, return 200 from `/health`, and serve MCP Streamable HTTP at `/mcp`.

## Deploy

Prerequisites: Terraform >= 1.5, AWS CLI, `kubectl`, AWS credentials allowed to create these resources, and access to the S3 state bucket in `backend.tf`.

```bash
cp terraform.tfvars.example terraform.tfvars   # first time only
# Set the account ID, image URI, repository ARN and public_allowed_cidrs (your IP as a /32).
./deploy.sh
```

`deploy.sh` runs `terraform init` and `terraform apply -auto-approve`, updates your kubeconfig, applies the manifests in `kubernetes/` (filling in the ECR registry for nginx), waits for the nginx rollout, and prints the nodes, namespaces, pods, deployments and services.

The MCP server policy is set in `terraform.tfvars`:

| Variable | Default | Effect |
|---|---|---|
| `mcp_allowed_deployments` | `["nginx"]` | Deployments the MCP server may change |
| `mcp_workload_ecr_repositories` | `["nginx"]` | ECR repositories `set_image` may deploy from and `list_image_tags` may read |
| `mcp_enable_remediation` | `true` | `false` puts the MCP server in read-only mode |

To preview changes without applying:

```bash
terraform init
terraform plan
```

Destroy all resources:

```bash
terraform destroy
```

## If your IP changes

`public_allowed_cidrs` controls access to both the ALB and the EKS public endpoint. Update it in `terraform.tfvars` and run `terraform apply` before connecting from a new network. For a live demo, prefer a phone hotspot to shared venue Wi-Fi. The bearer token still protects `/mcp`, but traffic is plain HTTP, so the token is visible to anyone who can watch the network.

## Cost

The EKS control plane, EKS Fargate pods, the ALB, the ECS Fargate task and the 8 interface endpoints all bill hourly while running. There is no NAT Gateway.
