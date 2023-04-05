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
  enable_external_dns                 = false
  aws_load_balancer_controller_helm_config = {
    service_account = "aws-lb-sa"
  }


  enable_karpenter                = false
  enable_secrets_store_csi_driver = false
  secrets_store_csi_driver_helm_config = {
    name       = "csi-secrets-store"
    chart      = "secrets-store-csi-driver"
    repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
    version    = "1.3.1"
    namespace  = "kube-system"
    set_values = [
      {
        name  = "syncSecret.enabled"
        value = "true"
      },
      {
        name  = "enableSecretRotation"
        value = "true"
      }
    ]
  }

  enable_secrets_store_csi_driver_provider_aws = false
  # csi_secrets_store_provider_aws_helm_config = {
  #   namespace = "kube-system"
  #   version   = "0.0.4"
  # }

  enable_metrics_server = false

}

#Wait about 2 minutes for the LoadBalancer creation, and get it's URL:
####export ARGOCD_SERVER=`kubectl get svc argo-cd-argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'`
####echo "https://$ARGOCD_SERVER"

#----------------------------------
#Query for ArgoCD admin password
#kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

#---------------------------------------------------------------
# AWS Application load balancer
#---------------------------------------------------------------

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
                name: backend-service
                port:
                  number: 5000
YAML

  depends_on = [module.eks_blueprints_kubernetes_addons]
}


#---------------------------------------------------------------
# External Secrets Operator - Secret
#---------------------------------------------------------------
resource "aws_secretsmanager_secret" "fe_secrets" {
  name                    = "TALY_FE_ENV"
  description             = "Environment secrets for application front end"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret" "be_secrets" {
  name                    = "TALY_BE_ENV"
  description             = "Environment secrets for application back end"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "fe" {
  secret_id = aws_secretsmanager_secret.fe_secrets.id
  secret_string = jsonencode({
    NEXT_PUBLIC_API_URL               = var.fe_secrets.NEXT_PUBLIC_API_URL,
    NEXT_PUBLIC_GOOGLE_AUTH_CLIENT_ID = var.fe_secrets.NEXT_PUBLIC_GOOGLE_AUTH_CLIENT_ID
  })
}

resource "aws_secretsmanager_secret_version" "be" {
  secret_id = aws_secretsmanager_secret.be_secrets.id
  secret_string = jsonencode({
    PORT                  = var.be_secrets.PORT,
    MONGO_URL             = var.be_secrets.MONGO_URL,
    GOOGLE_AUTH_CLIENT_ID = var.be_secrets.GOOGLE_AUTH_CLIENT_ID,
    ADMIN_EMAIL           = var.be_secrets.ADMIN_EMAIL,
    JWT_SECRET            = var.be_secrets.JWT_SECRET,
    FE_URL                = var.be_secrets.FE_URL,
    BE_URL                = var.be_secrets.BE_URL,
    ADMIN_SESSION_SECRET  = var.be_secrets.ADMIN_SESSION_SECRET,
    SENDGRID_API_KEY      = var.be_secrets.SENDGRID_API_KEY,
    SENDGRID_FROM         = var.be_secrets.SENDGRID_FROM,
    AWS_REGION            = var.be_secrets.AWS_REGION,
    AWS_BUCKET_NAME       = var.be_secrets.AWS_BUCKET_NAME
  })
}

module "cluster_secretstore_role" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints-addons/modules/irsa"

  kubernetes_namespace        = local.namespace
  create_kubernetes_namespace = false
  kubernetes_service_account  = local.secretstore_sa
  irsa_iam_policies           = [aws_iam_policy.cluster_secretstore.arn]
  eks_cluster_id              = module.eks_blueprints.eks_cluster_id
  eks_oidc_provider_arn       = module.eks_blueprints.eks_oidc_provider_arn

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}

resource "aws_iam_policy" "cluster_secretstore" {
  name_prefix = local.cluster_secretstore_sa
  policy      = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
    "Effect": "Allow",
    "Action": [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ],
    "Resource": [
      "${aws_secretsmanager_secret.fe_secrets.arn}",
      "${aws_secretsmanager_secret.be_secrets.arn}"
    ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "arn:aws:kms:${local.region}:${data.aws_caller_identity.current.account_id}:key/*"
    }
  ]
}
POLICY
}

resource "kubectl_manifest" "cluster_secretstore" {
  yaml_body = <<YAML
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: ${local.cluster_secretstore_name}
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: ${aws_secretsmanager_secret.fe_secrets.name}
        objectType: "secretsmanager"
        jmesPath:
          - path: NEXT_PUBLIC_API_URL
            objectAlias: api_endpoint
          - path: NEXT_PUBLIC_GOOGLE_AUTH_CLIENT_ID
            objectAlias: google_auth
      - objectName: ${aws_secretsmanager_secret.be_secrets.name}
        objectType: "secretsmanager"
        jmesPath:
          - path: PORT
            objectAlias: port
          - path: MONGO_URL
            objectAlias: mongo_endpoint
          - path: GOOGLE_AUTH_CLIENT_ID
            objectAlias: google_client
          - path: ADMIN_EMAIL
            objectAlias: admin_email
          - path: JWT_SECRET
            objectAlias: jwt
          - path: FE_URL
            objectAlias: fe_url
          - path: BE_URL
            objectAlias: be_url
          - path: ADMIN_SESSION_SECRET
            objectAlias: session_secret
          - path: SENDGRID_API_KEY
            objectAlias: sendgrid_api
          - path: SENDGRID_FROM
            objectAlias: sendgrid_from
          - path: AWS_REGION
            objectAlias: region
          - path: AWS_BUCKET_NAME
            objectAlias: bucket_name

  secretObjects:
    - secretName: frontendsecret
      type: Opaque
      data:
        - objectName: api_endpoint
          key: api_endpoint
        - objectName: google_auth
          key: google_auth
    - secretName: backendsecret
      type: Opaque
      data:
        - objectName: port
          key: port
        - objectName: mongo_endpoint
          key: mongo_endpoint
        - objectName: google_client
          key: google_client
        - objectName: admin_email
          key: admin_email
        - objectName: jwt
          key: jwt
        - objectName: fe_url
          key: fe_url
        - objectName: be_url
          key: be_url
        - objectName: session_secret
          key: session_secret
        - objectName: sendgrid_api
          key: sendgrid_api
        - objectName: sendgrid_from
          key: sendgrid_from
        - objectName: region
          key: region
        - objectName: bucket_name
          key: bucket_name
YAML

  depends_on = [module.eks_blueprints_kubernetes_addons]
}
