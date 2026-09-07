resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"

    labels = {
      managed-by = "terraform"
      purpose    = "observability"
    }
  }
}

resource "kubernetes_namespace_v1" "sre_practice" {
  metadata {
    name = "sre-practice"

    labels = {
      managed-by = "terraform"
      purpose    = "incident-practice"
    }
  }
}