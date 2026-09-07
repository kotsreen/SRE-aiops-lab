provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = "kind-sre-lab"
}

provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = "kind-sre-lab"
  }
}
