module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  eks_cluster_name     = local.eks_cluster_name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  enable_vpc_endpoints = var.enable_vpc_endpoints
  tags                 = var.tags
}

module "ecs" {
  source = "./modules/ecs"

  project_name                   = var.project_name
  environment                    = var.environment
  aws_region                     = var.aws_region
  vpc_id                         = module.vpc.vpc_id
  vpc_cidr                       = var.vpc_cidr
  s3_prefix_list_id              = module.vpc.s3_prefix_list_id
  cluster_name                   = local.name
  eks_cluster_name               = local.eks_cluster_name
  private_subnet_ids             = module.vpc.private_subnet_ids
  public_subnet_ids              = module.vpc.public_subnet_ids
  allowed_public_cidrs           = var.public_allowed_cidrs
  container_image                = var.container_image
  container_image_repository_arn = var.container_image_repository_arn
  container_port                 = var.container_port
  cpu                            = var.ecs_cpu
  memory                         = var.ecs_memory
  desired_count                  = var.ecs_desired_count
  health_check_path              = var.mcp_health_check_path
  mcp_kubernetes_namespace       = var.mcp_kubernetes_namespace
  log_retention_days             = var.log_retention_days
  task_execution_role_name       = var.task_execution_role_name
  task_role_name                 = var.task_role_name
  tags                           = local.tags
}

module "eks" {
  source = "./modules/eks"

  project_name          = var.project_name
  environment           = var.environment
  cluster_name          = local.eks_cluster_name
  kubernetes_version    = var.eks_kubernetes_version
  private_subnet_ids    = module.vpc.private_subnet_ids
  mcp_task_role_arn     = module.ecs.task_role_arn
  mcp_security_group_id = module.ecs.task_security_group_id
  mcp_namespace         = var.mcp_kubernetes_namespace
  public_access_cidrs   = var.public_allowed_cidrs
  log_retention_days    = var.log_retention_days
  tags                  = local.tags
}

