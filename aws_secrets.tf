#---------------------------------------------------------------
# External Secrets Operator - Secret
#---------------------------------------------------------------

resource "aws_kms_key" "secrets" {
  enable_key_rotation = true
}

resource "aws_secretsmanager_secret" "secret" {
  name                    = "FE_ENV"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "secret" {
  secret_id = aws_secretsmanager_secret.secret.id
  secret_string = jsonencode({
    NEXT_PUBLIC_API_URL           = var.fe_secrets.NEXT_PUBLIC_API_URL,
    NEXT_PUBLIC_BASE_API_ENDPOINT = var.fe_secrets.NEXT_PUBLIC_BASE_API_ENDPOINT
  })
}

module "cluster_secretstore_role" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.27.0/modules/irsa"

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
            "Resource": "${aws_secretsmanager_secret.secret.arn}"
            },
            {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": "${aws_kms_key.secrets.arn}"
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
      - objectName: ${aws_secretsmanager_secret.secret.name}
        objectType: "secretsmanager"
        jmesPath:
          - path: NEXT_PUBLIC_BASE_API_ENDPOINT
            objectAlias: api_endpoint
          - path: NEXT_PUBLIC_API_URL
            objectAlias: api_url

  secretObjects:
    - secretName: frontendsecret
      type: Opaque
      data:
        - objectName: api_endpoint
          key: endpoint
        - objectName: api_url
          key: api    
YAML

  depends_on = [module.eks_blueprints_kubernetes_addons]
}
