
locals {
  tmp_dir       = "${path.cwd}/.tmp"
  bin_dir      = module.setup_clis.bin_dir
  chart         = "${path.module}/charts/pact-broker"
  ingress_host  = "pact-broker-${var.releases_namespace}.${var.cluster_ingress_hostname}"
  service_url  = "http://pact-broker.${var.releases_namespace}"
  database_type = "sqlite"
  database_name = "pactbroker.sqlite"
  cluster_type  = var.cluster_type == "kubernetes" ? "kubernetes" : "openshift"
}

module setup_clis {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"

  clis = ["helm"]
}

resource null_resource print_toolkit_namespace {
  provisioner "local-exec" {
    command = "echo 'Toolkit namespace: ${var.toolkit_namespace}'"
  }
}

# resource "helm_release" "pactbroker" {
#   depends_on = [null_resource.print_toolkit_namespace]

#   chart      = "pact-broker"
#   name       = "pact-broker"
#   namespace  = var.releases_namespace
#   disable_openapi_validation = true
#   repository = "https://charts.cloudnativetoolkit.dev"
#   version    = "0.2.1"

#   set {
#     name  = "ingress.enabled"
#     value = var.cluster_type == "kubernetes" ? "true" : "false"
#   }

#   set {
#     name  = "route.enabled"
#     value = var.cluster_type == "kubernetes" ? "false" : "true"
#   }

#   set {
#     name  = "ingress.hosts.0.host"
#     value = local.ingress_host
#   }

#   set {
#     name  = "ingress.tls[0].secretName"
#     value = var.tls_secret_name
#   }

#   set {
#     name  = "ingress.tls[0].hosts[0]"
#     value = local.ingress_host
#   }

#   set {
#     name  = "database.type"
#     value = local.database_type
#   }

#   set {
#     name  = "database.name"
#     value = local.database_name
#   }
# }



resource null_resource pactbroker_helm {
  depends_on = [null_resource.delete-consolelink]

  triggers = {
    namespace = var.releases_namespace
    name = "pact-broker"
    chart = "pact-broker"
    ingress_host = local.ingress_host
    ingress_enabled = var.cluster_type == "kubernetes" ? "true" : "false"
    route_enabbled = var.cluster_type == "kubernetes" ? "false" : "true"
    database_type = local.database_type
    database_name = local.database_name
    tls_secret_name = var.tls_secret_name
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-pactbroker.sh ${self.triggers.chart} ${self.triggers.namespace} ${self.triggers.ingress_host} ${self.triggers.database_type} ${self.triggers.database_name} ${self.triggers.tls_secret_name} ${self.triggers.ingress_enabled} ${self.triggers.route_enabbled}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-pactbroker.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
    }
  }
}



resource "null_resource" "delete-consolelink" {
  count = var.cluster_type != "kubernetes" ? 1 : 0

  provisioner "local-exec" {
    command = "kubectl delete consolelink -l grouping=garage-cloud-native-toolkit -l app=pactbroker || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

# resource "helm_release" "pactbroker-config" {
#   depends_on = [helm_release.pactbroker, null_resource.delete-consolelink]

#   name         = "pactbroker-config"
#   repository   = "https://charts.cloudnativetoolkit.dev"
#   chart        = "tool-config"
#   namespace    = var.releases_namespace
#   force_update = true

#   set {
#     name  = "name"
#     value = "pactbroker"
#   }

#   set {
#     name  = "privateUrl"
#     value = local.service_url
#   }

#   set {
#     name  = "applicationMenu"
#     value = false
#   }
# }