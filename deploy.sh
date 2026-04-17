#!/usr/bin/env bash
# Deploy FlowBoard to Kubernetes.
# Usage: ./deploy.sh
set -euo pipefail

NAMESPACE="default"
APP_LABEL="app=jaseci"
TIMEOUT=300

# Check prerequisites
for cmd in kubectl jac; do
  command -v "$cmd" &>/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done

# Load .env
if [ -f .env ]; then
  set -a; source .env; set +a
else
  echo ".env not found. Copy .env.example to .env and fill in values." >&2
  exit 1
fi

echo "Checking for existing deployment..."
EXISTING=$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers 2>/dev/null | wc -l)
if [ "$EXISTING" -gt 0 ]; then
    echo "Deployment already running:"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL"
    echo "Run ./teardown.sh first if you want a fresh deployment."
    exit 1
fi

echo "Starting jac start --scale..."
jac start main.jac --scale &
JAC_PID=$!

echo "Waiting for jaseci pod to appear..."
ELAPSED=0
until kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers 2>/dev/null | grep -q .; do
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    if [ "$ELAPSED" -ge 60 ]; then
        echo "Timed out waiting for pod to appear." >&2
        kill "$JAC_PID" 2>/dev/null || true
        exit 1
    fi
done

# jac-scale network policies block DNS (port 53) egress — patch them to allow it.
echo "Patching network policies to allow DNS resolution..."
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

echo "Waiting for pod to become Ready (timeout: ${TIMEOUT}s)..."
if kubectl wait pod -n "$NAMESPACE" -l "$APP_LABEL" \
    --for=condition=Ready --timeout="${TIMEOUT}s"; then
    echo ""
    echo "Deployment ready!"
    kubectl get pods -n "$NAMESPACE"
    echo ""
    PUBLIC_IP=$(curl -sf --max-time 5 http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
    echo "FlowBoard is live at: http://${PUBLIC_IP}:30001/cl/app"
    echo "API docs:             http://${PUBLIC_IP}:30001/docs"
else
    echo "Pod did not become Ready within ${TIMEOUT}s." >&2
    echo "Check init container logs:" >&2
    echo "  kubectl logs -n $NAMESPACE -l $APP_LABEL -c wait-for-mongodb" >&2
    echo "  kubectl logs -n $NAMESPACE -l $APP_LABEL -c wait-for-redis" >&2
    echo "  kubectl logs -n $NAMESPACE -l $APP_LABEL" >&2
    kill "$JAC_PID" 2>/dev/null || true
    exit 1
fi
