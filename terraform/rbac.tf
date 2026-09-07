resource "kubernetes_service_account_v1" "incident_analyzer" {
  metadata {
    name      = "incident-analyzer"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }
}

resource "kubernetes_role_v1" "incident_analyzer" {
  metadata {
    name      = "incident-analyzer"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }

  # Read Kubernetes incident evidence
  rule {
    api_groups = [""]
    resources = [
      "pods",
      "events"
    ]

    verbs = [
      "get",
      "list",
      "watch"
    ]
  }

  # Read deployments / replica sets
  rule {
    api_groups = ["apps"]

    resources = [
      "deployments",
      "replicasets"
    ]

    verbs = [
      "get",
      "list",
      "watch"
    ]
  }

  # LAB ONLY:
  # Allow the analyzer to inject a fault only into sre-demo.
  rule {
    api_groups     = ["apps"]
    resources      = ["deployments"]
    resource_names = ["sre-demo"]
    verbs          = ["get", "patch"]
  }

  # Analyzer may update ONLY its incident summary.
  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["incident-summary"]

    verbs = [
      "get",
      "patch",
      "update"
    ]
  }
}

resource "kubernetes_role_binding_v1" "incident_analyzer" {
  metadata {
    name      = "incident-analyzer"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.incident_analyzer.metadata[0].name
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.incident_analyzer.metadata[0].name
  }
}
