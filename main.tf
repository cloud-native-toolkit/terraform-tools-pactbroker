
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

  clis = ["helm", "jq"]
}

resource null_resource print_toolkit_namespace {
  provisioner "local-exec" {
    command = "echo 'Toolkit namespace: ${var.toolkit_namespace}'"
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

resource null_resource pactbroker_helm {
  depends_on = [null_resource.delete-consolelink]

  triggers = {
    namespace = var.releases_namespace
    name = "pact-broker"
    chart = "toolkit-charts/pact-broker"
    ingress_host = local.ingress_host
    ingress_enabled = var.cluster_type == "kubernetes" ? "true" : "false"
    route_enabbled = var.cluster_type == "kubernetes" ? "false" : "true"
    database_type = local.database_type
    database_name = local.database_name
    tls_secret_name = var.tls_secret_name
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
    cluster_type = var.cluster_type
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-pactbroker.sh ${self.triggers.chart} ${self.triggers.namespace} ${self.triggers.ingress_host} ${self.triggers.database_type} ${self.triggers.database_name} ${self.triggers.tls_secret_name} ${self.triggers.ingress_enabled} ${self.triggers.route_enabbled} ${self.triggers.cluster_type}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-pactbroker.sh ${self.triggers.chart} ${self.triggers.namespace} ${self.triggers.ingress_host} ${self.triggers.database_type} ${self.triggers.database_name} ${self.triggers.tls_secret_name} ${self.triggers.ingress_enabled} ${self.triggers.route_enabbled} ${self.triggers.cluster_type}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
    }
  }
}