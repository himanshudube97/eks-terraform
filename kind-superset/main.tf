locals {
  clients = ["t4dsuperset", "clientb"]
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "kind-superset-kind"
  }
}

resource "helm_release" "superset" {
  for_each = toset(local.clients)

  name       = each.key
  repository = "https://apache.github.io/superset"
  chart      = "superset"
  version    = "0.14.2"
  namespace  = "${each.key}-superset" # Generates: clienta-superset, clientb-superset
  values     = [file("${path.module}/clients/${each.key}/values.yaml")]
}

resource "kubernetes_namespace" "ns" {
  for_each = toset(local.clients)

  metadata {
    name = "${each.key}-superset"
  }
}