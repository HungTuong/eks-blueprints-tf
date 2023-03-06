# module "kubernetes_addons" {
#   source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.25.0/modules/kubernetes-addons"

#   eks_cluster_id = module.eks_blueprints.eks_cluster_id

#   #---------------------------------------------------------------
#   # ARGO CD ADD-ON
#   #---------------------------------------------------------------

#   enable_argocd         = false
#   argocd_manage_add_ons = true # Indicates that ArgoCD is responsible for managing/deploying Add-ons.

#   argocd_applications = {
#     addons = local.addon_application
#     #workloads = local.workload_application #We comment it for now
#   }

#   argocd_helm_config = {
#     set = [
#       {
#         name  = "server.service.type"
#         value = "LoadBalancer"
#       }
#     ]
#   }

#   #---------------------------------------------------------------
#   # ADD-ONS - You can add additional addons here
#   # https://aws-ia.github.io/terraform-aws-eks-blueprints/add-ons/
#   #---------------------------------------------------------------


#   enable_aws_load_balancer_controller = true
#   enable_karpenter                    = false
#   enable_secrets_store_csi_driver     = true
#   enable_metrics_server               = false

# }

# #Wait about 2 minutes for the LoadBalancer creation, and get it's URL:
# ####export ARGOCD_SERVER=`kubectl get svc argo-cd-argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'`
# ####echo "https://$ARGOCD_SERVER"

# #----------------------------------
# #Query for ArgoCD admin password
# #kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
