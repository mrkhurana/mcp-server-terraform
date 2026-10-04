# Private EKS and ECS MCP Infrastructure

This Terraform repository provisions AWS infrastructure for a private MCP service connected to a private EKS cluster. It creates an ECS Fargate task definition and service using an image from an **existing private ECR repository**. Terraform does not create the repository or build/push the image.

## Architecture

```text
AWS VPC (no NAT or Internet Gateway)
├── Private subnets
│   ├── EKS managed nodes
│   ├── ECS Fargate MCP tasks (no public IP)
│   ├── Internal Application Load Balancer (HTTP :8080)
│   └── private AWS service endpoints
├── Private EKS Kubernetes API endpoint
└── CloudWatch log groups
```

The internal ALB DNS name is exposed as `internal_load_balancer_dns_name`; `internal_mcp_url` is `http://<internal-alb-dns>:8080/mcp`. It resolves and routes only from inside the VPC. No ACM, TLS, public ALB, Route 53, VPC Lattice, public NAT Gateway, or external internet exposure are created.

This repo is aligned to the public MCP runtime path. The infrastructure provisions the ECS MCP service, the public ALB, and the EKS cluster with a restricted source CIDR allowlist. The MCP runtime is the core operational path, and any future AgentCore or model layer can attach to the public end point once enabled separately.

The task security group accepts port 8080 only from the internal ALB security group. The ALB accepts port 8080 only from the VPC CIDR. ECS tasks have no public IP and egress only to TCP 443 within the VPC plus the S3 gateway endpoint.

## Modules

- `modules/vpc`: VPC, private subnets/route tables, ECR/EC2/CloudWatch Logs interface endpoints, S3 gateway endpoint, endpoint security group.
- `modules/eks`: private EKS control plane, managed node group, control-plane logs, and namespace-scoped EKS view access for the ECS task role.
- `modules/ecs`: ECS cluster, Fargate task definition/service, internal ALB/listener/target group, task and execution roles, security groups, and CloudWatch logs.

## Image prerequisite

Create and push the MCP image to a private ECR repository before applying. Set both `container_image` and `container_image_repository_arn` in `terraform.tfvars`. The configured health-check path (default `/health`) must return an HTTP 200-399 response. The image must listen on `0.0.0.0:8080` and expose Streamable HTTP at `/mcp`.

Terraform does not manage the ECR repository, build images, push images, or create Kubernetes application workloads.

## EKS permissions

The ECS task role has `eks:DescribeCluster` on the configured cluster. An EKS access entry maps that role to the AWS-managed `AmazonEKSViewPolicy` scoped to the configured namespace (default `application`). This supports read-only investigation. It does not grant `delete pods`; the `restart_pod` tool requires a namespace Role/RoleBinding granting only `delete` on `pods`. That write RBAC is intentionally not granted by this infrastructure until explicitly added and reviewed. ECS tasks can reach the private EKS API over TCP 443 through the task SG to the cluster security group.

The application can use the task role to call `DescribeCluster`, retrieve endpoint and CA information, generate EKS IAM authentication, and connect using the official Kubernetes client. This repository creates no MCP application code or Kubernetes provider resources.

## Cost and private networking

- No NAT Gateway or Internet Gateway is provisioned.
- ECR API, ECR Docker, EC2, and CloudWatch Logs interface endpoints plus an S3 gateway endpoint support private ECR pulls, node APIs, and log delivery. Interface endpoints incur hourly and data-processing charges and are placed in one private subnet to reduce hourly cost.
- The EKS control plane, managed EC2 node, internal ALB, and ECS Fargate task incur charges while running.
- ECR endpoints remain in the VPC for pulls, but no ECR repository is created by this project.

## Deploy

Prerequisites: Terraform >= 1.5, AWS credentials with permissions to create the infrastructure, two available AZs, and an existing private ECR image URI/repository ARN.

```bash
cp terraform.tfvars.example terraform.tfvars
# Replace the example account ID, region, image URI, and repository ARN.
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply -auto-approve
```

Destroy all resources with:

```bash
terraform destroy -auto-approve
```

`terraform plan` and `terraform validate` do not create resources. No secrets are output.
