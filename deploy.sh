#!/usr/bin/env bash
# Deploy FlowBoard to Kubernetes.
# Usage: ./deploy.sh
set -euo pipefail

NAMESPACE="default"
APP_LABEL="app=jaseci"
JAC_SCALE_TIMEOUT=120   # jac start --scale blocks forever; timeout is expected (exit 124)
READY_TIMEOUT=300       # seconds to wait for pod readiness after deploy

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# Check prerequisites
for cmd in kubectl jac; do
  command -v "$cmd" &>/dev/null || die "Missing required command: $cmd"
done

# Load .env
if [ -f .env ]; then
  set -a; source .env; set +a
else
  die ".env not found. Copy .env.example to .env and fill in values."
fi

# Check for existing deployment
EXISTING=$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers 2>/dev/null | wc -l)
if [ "$EXISTING" -gt 0 ]; then
    log "Deployment already running:"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL"
    log "Run ./teardown.sh first if you want a fresh deployment."
    exit 1
fi

# Install jac dependencies
log "Installing app dependencies..."
jac install

# Deploy — jac start --scale blocks (non-daemon); timeout after JAC_SCALE_TIMEOUT seconds is expected
log "Running jac start --scale (will timeout after ${JAC_SCALE_TIMEOUT}s — this is expected)..."
timeout "$JAC_SCALE_TIMEOUT" jac start main.jac --scale || {
  EXIT=$?
  if [ "$EXIT" -eq 124 ]; then
    log "jac start timed out after ${JAC_SCALE_TIMEOUT}s — expected, deployment is running in k8s"
  else
    die "jac start failed with exit code $EXIT"
  fi
}

# Fix jac-scale network policies — they block DNS and intra-namespace pod traffic
log "Patching network policies to allow DNS and intra-namespace traffic..."
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
EOF

kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intra-namespace
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector: {}
  egress:
    - to:
        - podSelector: {}
EOF

# Fix busybox nc -z incompatibility (Oracle Cloud / some k8s distros ship a
# busybox build where nc -z exits non-zero even on success). Replace both init
# container health checks with plain nc (no -z) which works everywhere.
log "Patching init container health checks for busybox nc compatibility..."
kubectl patch deployment jaseci -n "$NAMESPACE" --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/initContainers/0/command",
   "value":["sh","-c","until nc jaseci-mongodb-service 27017 </dev/null 2>/dev/null; do echo waiting for mongodb; sleep 3; done"]},
  {"op":"replace","path":"/spec/template/spec/initContainers/1/command",
   "value":["sh","-c","until nc jaseci-redis-service 6379 </dev/null 2>/dev/null; do echo waiting for redis; sleep 3; done"]}
]'

# Restart pod so it picks up the network policy changes and the nc fix
log "Restarting jaseci pod to pick up network policy changes..."
kubectl rollout restart deployment/jaseci -n "$NAMESPACE"

# Wait for readiness
log "Waiting for pod to become Ready (timeout: ${READY_TIMEOUT}s)..."
if kubectl wait pod -n "$NAMESPACE" -l "$APP_LABEL" \
    --for=condition=Ready --timeout="${READY_TIMEOUT}s"; then
    log ""
    log "Deployment ready!"
    kubectl get pods -n "$NAMESPACE"
    log ""
    PUBLIC_IP=$(curl -sf --max-time 5 http://checkip.amazonaws.com 2>/dev/null || hostname -I | awk '{print $1}')
    log "FlowBoard is live at: http://${PUBLIC_IP}:30001/cl/app"
    log "API docs:             http://${PUBLIC_IP}:30001/docs"
else
    log "Pod did not become Ready within ${READY_TIMEOUT}s."
    log "Debug with:"
    log "  kubectl logs -n $NAMESPACE -l $APP_LABEL -c wait-for-mongodb"
    log "  kubectl logs -n $NAMESPACE -l $APP_LABEL -c wait-for-redis"
    log "  kubectl logs -n $NAMESPACE -l $APP_LABEL"
    exit 1
fi
