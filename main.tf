provider "helm" {
  version = ">= 1.1.1"

  kubernetes {
    config_path = var.cluster_config_file
  }
}

locals {
  tmp_dir       = "${path.cwd}/.tmp"
  chart         = "${path.module}/charts/pact-broker"
  ingress_host  = "pact-${var.releases_namespace}.${var.cluster_ingress_hostname}"
  ingress_url   = "http://${local.ingress_host}"
  database_type = "sqlite"
  database_name = "pactbroker.sqlite"
  secret_name   = "pactbroker-access"
  config_name   = "pactbroker-config"
  cluster_type  = var.cluster_type == "kubernetes" ? "kubernetes" : "openshift"
}

resource "helm_release" "pactbroker" {
  chart     = local.chart
  name      = "pact-broker"
  namespace = var.releases_namespace
  disable_openapi_validation = true

  set {
    name  = "ingress.enabled"
    value = var.cluster_type == "kubernetes" ? "true" : "false"
  }

  set {
    name  = "route.enabled"
    value = var.cluster_type == "kubernetes" ? "false" : "true"
  }

  set {
    name  = "ingress.hosts.0.host"
    value = local.ingress_host
  }

  set {
    name  = "ingress.tls[0].secretName"
    value = var.tls_secret_name
  }

  set {
    name  = "ingress.tls[0].hosts[0]"
    value = local.ingress_host
  }

  set {
    name  = "database.type"
    value = local.database_type
  }

  set {
    name  = "database.name"
    value = local.database_name
  }
}

resource "helm_release" "pactbroker-config" {
  depends_on = [helm_release.pactbroker]

  name         = "pactbroker-config"
  repository   = "https://ibm-garage-cloud.github.io/toolkit-charts/"
  chart        = "tool-config"
  namespace    = var.releases_namespace
  force_update = true

  set {
    name  = "name"
    value = "pactbroker"
  }

  set {
    name  = "url"
    value = local.ingress_url
  }
}