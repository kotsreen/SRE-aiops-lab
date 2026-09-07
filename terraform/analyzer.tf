resource "kubernetes_config_map_v1" "analyzer_code" {
  metadata {
    name      = "incident-analyzer-code"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }

  data = {
    "app.py" = file(
      "${path.module}/../analyzer/app.py"
    )

    "requirements.txt" = file(
      "${path.module}/../analyzer/requirements.txt"
    )
  }
}

resource "kubernetes_config_map_v1" "runbooks" {
  metadata {
    name      = "sre-runbooks"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }

  data = {
    "imagepullbackoff.md" = file(
      "${path.module}/../runbooks/imagepullbackoff.md"
    )

    "crashloopbackoff.md" = file(
      "${path.module}/../runbooks/crashloopbackoff.md"
    )

    "high-cpu.md" = file(
      "${path.module}/../runbooks/high-cpu.md"
    )
  }
}

resource "kubernetes_deployment_v1" "incident_analyzer" {

  metadata {
    name      = "incident-analyzer"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "incident-analyzer"
      }
    }

    template {
      metadata {
        labels = {
          app = "incident-analyzer"
        }

        annotations = {
          "checksum/analyzer-code" = sha256(join("", [
            file("${path.module}/../analyzer/app.py"),
            file("${path.module}/../analyzer/requirements.txt")
          ]))

          "checksum/runbooks" = sha256(join("", [
            file("${path.module}/../runbooks/imagepullbackoff.md"),
            file("${path.module}/../runbooks/crashloopbackoff.md"),
            file("${path.module}/../runbooks/high-cpu.md")
          ]))
        }
      }

      spec {
        service_account_name = (
          kubernetes_service_account_v1
          .incident_analyzer
          .metadata[0]
          .name
        )

        container {
          name  = "incident-analyzer"
          image = "python:3.12-slim"

          command = [
            "/bin/sh",
            "-c"
          ]

          args = [
            "pip install --no-cache-dir -r /app/requirements.txt && python -m uvicorn app:app --app-dir /app --host 0.0.0.0 --port 8000"
          ]

          env {
            name  = "NAMESPACE"
            value = "sre-practice"
          }

          env {
            name  = "OLLAMA_URL"
            value = "http://host.docker.internal:11434"
          }

          env {
            name  = "OLLAMA_MODEL"
            value = var.ollama_model
          }

          port {
            container_port = 8000
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }

            initial_delay_seconds = 15
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }

            initial_delay_seconds = 30
            period_seconds        = 20
          }

          volume_mount {
            name       = "analyzer-code"
            mount_path = "/app"
            read_only  = true
          }

          volume_mount {
            name       = "runbooks"
            mount_path = "/runbooks"
            read_only  = true
          }
        }

        volume {
          name = "analyzer-code"

          config_map {
            name = kubernetes_config_map_v1.analyzer_code.metadata[0].name
          }
        }

        volume {
          name = "runbooks"

          config_map {
            name = kubernetes_config_map_v1.runbooks.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_role_binding_v1.incident_analyzer
  ]
}

resource "kubernetes_service_v1" "incident_analyzer" {

  metadata {
    name      = "incident-analyzer"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }

  spec {
    selector = {
      app = "incident-analyzer"
    }

    port {
      port        = 8000
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_config_map_v1" "incident_summary" {
  metadata {
    name      = "incident-summary"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }

  data = {
    "summary.json" = jsonencode({
      status        = "NO_ACTIVE_INCIDENT"
      incident_id   = ""
      incident_type = ""
      application   = "sre-demo"
      namespace     = "sre-practice"
    })
  }
}
