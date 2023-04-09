module "eks_blueprints_kubernetes_addons" {
  # source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons"
  # eks_cluster_id = module.eks_blueprints.eks_cluster_id

  # parameter for aws-ia/terraform-aws-eks-blueprints-addons
  source            = "github.com/aws-ia/terraform-aws-eks-blueprints-addons"
  cluster_name      = module.eks_blueprints.eks_cluster_id
  oidc_provider_arn = module.eks_blueprints.eks_oidc_provider_arn
  oidc_provider     = module.eks_blueprints.oidc_provider
  cluster_endpoint  = module.eks_blueprints.eks_cluster_endpoint
  cluster_version   = local.cluster_version



  #   #---------------------------------------------------------------
  #   # ARGO CD ADD-ON
  #   #---------------------------------------------------------------

  #   enable_argocd         = false
  #   argocd_manage_add_ons = false # Indicates that ArgoCD is responsible for managing/deploying Add-ons.

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

  #---------------------------------------------------------------
  # ADD-ONS - You can add additional addons here
  # https://aws-ia.github.io/terraform-aws-eks-blueprints/add-ons/
  #---------------------------------------------------------------


  enable_aws_load_balancer_controller = true
  enable_karpenter                    = true
  karpenter_helm_config = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }
  karpenter_node_iam_instance_profile        = module.karpenter.instance_profile_name
  karpenter_enable_spot_termination_handling = true

  enable_metrics_server = false

}

#Wait about 2 minutes for the LoadBalancer creation, and get it's URL:
####export ARGOCD_SERVER=`kubectl get svc argo-cd-argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'`
####echo "https://$ARGOCD_SERVER"

#----------------------------------
#Query for ArgoCD admin password
#kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d


################################################################################
# Karpenter
################################################################################
# Creates Karpenter native node termination handler resources and IAM instance profile
module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name           = module.eks_blueprints.cluster_name
  irsa_oidc_provider_arn = module.eks_blueprints.oidc_provider_arn
  create_irsa            = false # IRSA will be created by the kubernetes-addons module

  tags = local.tags
}


resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: karpenter-default
    spec:
      amiFamily: Bottlerocket
      blockDeviceMappings:
      # Root device
      - deviceName: /dev/xvda
        ebs:
          volumeSize: 10Gi
          volumeType: gp3
          encrypted: true
          deleteOnTermination: true
      # Data device: Container resources such as images and logs
      - deviceName: /dev/xvdb
        ebs:
          volumeSize: 20Gi
          volumeType: gp3
          encrypted: true
      subnetSelector:
        karpenter.sh/discovery: ${module.eks_blueprints.cluster_name}
        # kubernetes.io/cluster/${module.eks_blueprints.cluster_name}: '*'
        # kubernetes.io/role/internal-elb: '1' # to select only private subnets
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks_blueprints.cluster_name}
        # aws:eks:cluster-name: ${module.eks_blueprints.cluster_name}
      instanceProfile: ${module.karpenter.instance_profile_name}
      tags:
        karpenter.sh/cluster_name: ${module.eks_blueprints.cluster_name}
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2
        httpTokens: required
  YAML

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["c", "m", "r", "t]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4", "8", "16"]
        - key: "karpenter.k8s.aws/instance-hypervisor"
          operator: In
          values: ["nitro"]
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ${jsonencode(local.azs)}
        - key: "kubernetes.io/arch"
          operator: In
          values: ["arm64", "amd64"]
        - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
          operator: In
          values: ["spot"]
      kubeletConfiguration:
        containerRuntime: containerd
        maxPods: 110
      limits:
        resources:
          cpu: "16"
          memory: 64Gi
      consolidation:
        enabled: true
      providerRef:
        name: default
      ttlSecondsUntilExpired: 2592000 # 30 Days = 60 * 60 * 24 * 30 Seconds
  YAML

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}
