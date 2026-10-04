#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

command -v terraform >/dev/null 2>&1 || { echo "terraform is required" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "aws CLI is required" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required" >&2; exit 1; }

if [[ ! -f terraform.tfvars ]]; then
  echo "terraform.tfvars is required before deployment. Copy from terraform.tfvars.example and populate required values." >&2
  exit 1
fi

REGION="${AWS_REGION:-$(awk -F'=' '/^aws_region/ {gsub(/[" ]/, "", $2); print $2}' terraform.tfvars)}"

terraform init
terraform apply -auto-approve

CLUSTER_NAME="$(terraform output -raw eks_cluster_name)"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/rbac.yaml
kubectl apply -f kubernetes/nginx.yaml
kubectl -n application rollout status deployment/nginx --timeout=180s

kubectl get nodes
kubectl get ns
kubectl get pods -n application
kubectl get deployment -n application
kubectl get svc -n application

printf '\nRuntime infrastructure is ready.\n'
