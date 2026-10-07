#!/usr/bin/env bash
# Inject faults into the nginx workload for the live demo. The agent is never told which ones.
#   ./break.sh scale-zero   no replicas: Service has no endpoints          -> scale_deployment
#   ./break.sh readiness    pod stays Running but NotReady (403 on /)      -> restart_pod
#   ./break.sh bad-image    rollout to a tag that doesn't exist            -> rollback_deployment
#   ./break.sh oom          memory limit too small: OOMKilled / CrashLoop  -> update_resources
#   ./break.sh reset        put everything back (replaces the Deployment with nginx.yaml)
# Combine faults in one call, e.g. ./break.sh bad-image scale-zero (bad-image + oom is a single
# change, so one rollback undoes both). Add --kill to bad-image or oom to stop the existing pod too.
set -euo pipefail

NS=application
DEPLOY=nginx
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../.."
ECR_REGISTRY="$(awk -F'=' '/^container_image[ ]/ {gsub(/[" ]/, "", $2); print $2}' "$TF_DIR/terraform.tfvars" | cut -d'/' -f1)"

usage() { sed -n '2,9p' "$0"; exit 1; }
die() { echo "break.sh: $*" >&2; exit 1; }

KILL=false
SCALE_ZERO=false READINESS=false BAD_IMAGE=false OOM=false RESET=false
COUNT=0
for arg in "$@"; do
  case "$arg" in
    --kill) KILL=true; continue ;;
    scale-zero) $SCALE_ZERO && die "scale-zero given twice"; SCALE_ZERO=true ;;
    readiness)  $READINESS && die "readiness given twice";   READINESS=true ;;
    bad-image)  $BAD_IMAGE && die "bad-image given twice";   BAD_IMAGE=true ;;
    oom)        $OOM && die "oom given twice";               OOM=true ;;
    reset)      $RESET && die "reset given twice";           RESET=true ;;
    *) echo "break.sh: unknown fault '$arg'" >&2; usage ;;
  esac
  COUNT=$((COUNT + 1))
done
(( COUNT > 0 )) || usage

if $RESET; then
  (( COUNT == 1 )) && ! $KILL || die "reset can't be combined with other faults or --kill"
  sed "s|<ECR_REGISTRY>|${ECR_REGISTRY}|g" "$TF_DIR/kubernetes/nginx.yaml" | kubectl replace -f -
  kubectl -n "$NS" rollout restart deployment/"$DEPLOY"
  kubectl -n "$NS" rollout status deployment/"$DEPLOY" --timeout=180s
  exit 0
fi

# Combinations where one fault would silently undo another.
if $READINESS && $SCALE_ZERO; then
  die "readiness + scale-zero: scaling to 0 deletes the pod that readiness broke"
fi
if $READINESS && $KILL && { $BAD_IMAGE || $OOM; }; then
  die "readiness + --kill with bad-image/oom: the broken pod would be replaced by a fresh one"
fi
if $KILL && ! { $BAD_IMAGE || $OOM; }; then
  $SCALE_ZERO && echo "--kill: not needed, scale-zero already stops every pod."
  $READINESS && echo "--kill: ignored, a fresh pod would be healthy and undo the readiness fault."
  KILL=false
fi

planned=()
$READINESS && planned+=(readiness)
$BAD_IMAGE && planned+=(bad-image)
$OOM && planned+=(oom)
$SCALE_ZERO && planned+=(scale-zero)
$KILL && planned+=(--kill)
echo "Injecting: ${planned[*]}"

# 1. readiness first: it needs a running pod to break.
if $READINESS; then
  POD="$(kubectl -n "$NS" get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')"
  [[ -n "$POD" ]] || die "readiness needs a running nginx pod, and there is none"
  kubectl -n "$NS" exec "$POD" -- rm -f /usr/share/nginx/html/index.html
  echo "Removed index.html in $POD; readiness probe on / now returns 403."
fi

# 2. bad-image and/or oom as one pod-template change, so it is a single revision.
if $BAD_IMAGE || $OOM; then
  if $KILL; then
    # A rolling update keeps the old healthy pod serving until the new one is ready, which a broken
    # pod never is. With Recreate, Kubernetes stops the existing pod first; reset restores RollingUpdate.
    kubectl -n "$NS" patch deployment/"$DEPLOY" --type=merge \
      -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
    echo "--kill: strategy set to Recreate, the existing pod will be stopped (run ./break.sh reset to restore)."
  fi
  container='"name":"nginx"'
  $BAD_IMAGE && container+=",\"image\":\"${ECR_REGISTRY}/nginx:9.99-does-not-exist\""
  $OOM && container+=',"resources":{"limits":{"memory":"4Mi"},"requests":{"memory":"4Mi"}}'
  kubectl -n "$NS" patch deployment/"$DEPLOY" \
    -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{${container}}]}}}}"
fi

# 3. scale-zero last, so the other faults are already in the pod template when someone scales up.
if $SCALE_ZERO; then
  kubectl -n "$NS" scale deployment/"$DEPLOY" --replicas=0
fi
