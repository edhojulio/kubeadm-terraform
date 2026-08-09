#!/bin/bash
# -----------------------------------------------------------------------------
# install-ingress.sh
#
# Installs ingress-nginx and binds it to the node host network on ports 80/443
# so the GCP firewall can expose a single HTTP/HTTPS front door (no NodePort).
#
# Usage: sudo ./install-ingress.sh
#        (or run via master-init.sh after Calico is configured)
# -----------------------------------------------------------------------------

set -euo pipefail

INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-controller-v1.15.1}"
INGRESS_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/baremetal/deploy.yaml"

echo "--- Installing ingress-nginx (${INGRESS_NGINX_VERSION}) ---"
kubectl apply -f "${INGRESS_MANIFEST}"

echo "--- Waiting for ingress-nginx controller deployment ---"
kubectl -n ingress-nginx wait --for=condition=available deployment/ingress-nginx-controller --timeout=300s

echo "--- Binding controller to hostNetwork (node :80 / :443) ---"
kubectl -n ingress-nginx patch deployment ingress-nginx-controller --type=strategic -p '{
  "spec": {
    "template": {
      "spec": {
        "hostNetwork": true,
        "dnsPolicy": "ClusterFirstWithHostNet"
      }
    }
  }
}'

# External traffic hits the node directly; keep the Service as ClusterIP for webhook/internal use.
kubectl -n ingress-nginx patch svc ingress-nginx-controller --type=merge -p '{"spec":{"type":"ClusterIP"}}'

echo "--- Waiting for rolled-out hostNetwork controller ---"
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s

echo ""
echo "ingress-nginx is ready on worker node ports 80 (HTTP) and 443 (HTTPS)."
echo "Point Ingress resources at ingressClassName: nginx"
echo ""
