module "eks_blueprints_kubernetes_addons" {
  source         = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons"
  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  # # parameter for aws-ia/terraform-aws-eks-blueprints-addons
  # source            = "github.com/aws-ia/terraform-aws-eks-blueprints-addons"
  # cluster_name      = module.eks_blueprints.eks_cluster_id
  # oidc_provider_arn = module.eks_blueprints.eks_oidc_provider_arn
  # oidc_provider     = module.eks_blueprints.oidc_provider
  # cluster_endpoint  = module.eks_blueprints.eks_cluster_endpoint
  # cluster_version   = local.cluster_version

  enable_argocd = false

  enable_aws_load_balancer_controller = true
  enable_karpenter                    = true
  karpenter_helm_config = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }
  karpenter_node_iam_instance_profile        = module.karpenter.instance_profile_name
  karpenter_enable_spot_termination_handling = true

  enable_external_dns = true
  eks_cluster_domain  = local.domain

  enable_metrics_server                = true
  enable_amazon_eks_aws_ebs_csi_driver = true
}

# #Wait about 2 minutes for the LoadBalancer creation, and get it's URL:
# ####export ARGOCD_SERVER=`kubectl get svc argo-cd-argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'`
# ####echo "https://$ARGOCD_SERVER"

# #----------------------------------
# #Query for ArgoCD admin password
# #kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d


################################################################################
# Karpenter
################################################################################
# Creates Karpenter native node termination handler resources and IAM instance profile
module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name           = module.eks_blueprints.eks_cluster_id
  irsa_oidc_provider_arn = module.eks_blueprints.eks_oidc_provider_arn
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
      instanceProfile: "${local.project}-${local.node_group_name}"
      amiFamily: Bottlerocket
      blockDeviceMappings:
      # Root device
      - deviceName: /dev/xvda
        ebs:
          volumeSize: 20Gi
          volumeType: gp3
          encrypted: true
          deleteOnTermination: true
      subnetSelector:
        kubernetes.io/cluster/${module.eks_blueprints.eks_cluster_id}: '*'
        kubernetes.io/role/internal-elb: '1' # to select only private subnets
      securityGroupSelector:
        Name: "*node*"
      tags:
        karpenter.sh/cluster_name: ${module.eks_blueprints.eks_cluster_id}
        Name: thesis-btl-x86
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
          values: ["c", "m", "r", "t"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4"]
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
      limits:
        resources:
          cpu: "16"
          memory: 64Gi
      labels:
        type: karpenter
      providerRef:
        name: karpenter-default
      ttlSecondsUntilExpired: 2592000 # 30 Days = 60 * 60 * 24 * 30 Seconds
      ttlSecondsAfterEmpty: 30
  YAML

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}
