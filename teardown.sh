#!/usr/bin/env bash
# Tear down FlowBoard Kubernetes deployment.
# Usage: ./teardown.sh
set -euo pipefail

NAMESPACE="default"

echo "Tearing down FlowBoard deployment..."

kubectl delete all --all -n "$NAMESPACE" 2>/dev/null \
    && echo "  Deleted pods, services, deployments" \
    || echo "  Nothing to delete (all)"
kubectl delete pvc --all -n "$NAMESPACE" 2>/dev/null \
    && echo "  Deleted PVCs" \
    || echo "  No PVCs"
kubectl delete configmap --all -n "$NAMESPACE" 2>/dev/null \
    && echo "  Deleted ConfigMaps" \
    || echo "  No ConfigMaps"
kubectl delete secret --all -n "$NAMESPACE" 2>/dev/null \
    && echo "  Deleted secrets" \
    || echo "  No secrets"
kubectl delete networkpolicy --all -n "$NAMESPACE" 2>/dev/null \
    && echo "  Deleted NetworkPolicies" \
    || echo "  No NetworkPolicies"

echo ""
echo "Teardown complete. Run ./deploy.sh to redeploy."
