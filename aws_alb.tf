resource "kubectl_manifest" "cluster_ingress" {
  yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: taly-ingress
  labels:
    type: ingress
  annotations:
    alb.ingress.kubernetes.io/subnets: ${replace(join(", ", module.vpc.public_subnets), "\"", "")}
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 8000 
YAML

  depends_on = [module.eks_blueprints_kubernetes_addons]
}
