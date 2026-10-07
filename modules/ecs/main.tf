locals {
  name         = "${var.project_name}-${var.environment}"
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  workload_repository_arns = [
    for repo in var.mcp_workload_ecr_repositories :
    "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${repo}"
  ]
}

# Bearer token clients must send to /mcp. Stored as an SSM SecureString (the VPC already has an
# ssm endpoint) and injected into the container as MCP_AUTH_TOKEN. It is also kept in Terraform state.
resource "random_password" "mcp_auth_token" {
  length  = 48
  special = false
}

resource "aws_ssm_parameter" "mcp_auth_token" {
  name        = "/${local.name}/mcp-auth-token"
  description = "Bearer token for the AI Ops MCP endpoint."
  type        = "SecureString"
  value       = random_password.mcp_auth_token.result

  tags = var.tags
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/ecs/${local.name}"
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_ecs_cluster" "this" {
  name = local.name

  tags = merge(var.tags, {
    Name        = local.name
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-public-alb-sg"
  description = "Public MCP ALB ingress from approved client IPs."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP MCP traffic from allowed public source CIDRs"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_public_cidrs
  }

  egress {
    description = "Forward MCP traffic to ECS tasks in the VPC"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, {
    Name        = "${local.name}-public-alb-sg"
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_security_group" "tasks" {
  name        = "${local.name}-tasks-sg"
  description = "Private MCP tasks accept traffic only from the internal ALB."
  vpc_id      = var.vpc_id

  ingress {
    description     = "MCP HTTP from internal ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS to private EKS API and VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  dynamic "egress" {
    for_each = var.s3_prefix_list_id != "" ? [var.s3_prefix_list_id] : []

    content {
      description     = "HTTPS to S3 through the gateway endpoint"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      prefix_list_ids = [egress.value]
    }
  }

  tags = merge(var.tags, {
    Name        = "${local.name}-tasks-sg"
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_lb" "this" {
  name               = replace("${local.name}-mcp", "_", "-")
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = merge(var.tags, {
    Name        = "${local.name}-mcp-public"
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_lb_target_group" "this" {
  name        = replace("${local.name}-mcp-tg", "_", "-")
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.container_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_iam_role" "execution" {
  name = coalesce(var.task_execution_role_name, "${local.name}-execution")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "execution" {
  name = "${local.name}-execution-policy"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = var.container_image_repository_arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.this.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameters"]
        Resource = aws_ssm_parameter.mcp_auth_token.arn
      }
    ]
  })
}

resource "aws_iam_role" "task" {
  name = coalesce(var.task_role_name, "${local.name}-task")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "task_eks_describe" {
  name = "${local.name}-eks-describe"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}"
    }]
  })
}

resource "aws_iam_role_policy" "task_ecr_read" {
  count = length(var.mcp_workload_ecr_repositories) > 0 ? 1 : 0
  name  = "${local.name}-ecr-read"
  role  = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ecr:DescribeRepositories", "ecr:DescribeImages"]
      Resource = local.workload_repository_arns
    }]
  })
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "mcp-server"
      image     = var.container_image
      essential = true
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        { name = "PORT", value = tostring(var.container_port) },
        { name = "MCP_PORT", value = tostring(var.container_port) },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "EKS_CLUSTER_NAME", value = var.eks_cluster_name },
        { name = "ALLOWED_NAMESPACES", value = var.mcp_kubernetes_namespace },
        { name = "K8S_NAMESPACE_ALLOWLIST", value = var.mcp_kubernetes_namespace },
        { name = "MCP_ALLOWED_HOSTS", value = "${aws_lb.this.dns_name}:${var.container_port}" },
        { name = "MCP_TRANSPORT", value = "streamable-http" },
        { name = "MCP_ENABLE_REMEDIATION", value = tostring(var.mcp_enable_remediation) },
        { name = "MCP_ALLOWED_DEPLOYMENTS", value = join(",", var.mcp_allowed_deployments) },
        { name = "MCP_MIN_REPLICAS", value = "1" },
        { name = "MCP_MAX_REPLICAS", value = "5" },
        { name = "MCP_ALLOWED_ECR_REPOSITORIES", value = join(",", var.mcp_workload_ecr_repositories) },
        {
          name  = "MCP_ALLOWED_IMAGE_PREFIXES"
          value = join(",", [for repo in var.mcp_workload_ecr_repositories : "${local.ecr_registry}/${repo}"])
        }
      ]
      secrets = [
        { name = "MCP_AUTH_TOKEN", valueFrom = aws_ssm_parameter.mcp_auth_token.arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "mcp"
        }
      }
    }
  ])

  depends_on = [aws_iam_role_policy.execution]

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "mcp-server"
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = 60

  depends_on = [aws_lb_listener.http]

  tags = var.tags
}
