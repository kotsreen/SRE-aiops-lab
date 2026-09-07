resource "kubernetes_deployment_v1" "sre_demo" {
  metadata {
    name      = "sre-demo"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name

    labels = {
      app = "sre-demo"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "sre-demo"
      }
    }

    template {
      metadata {
        labels = {
          app = "sre-demo"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "128Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }

            initial_delay_seconds = 5
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }

            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "sre_demo" {
  metadata {
    name      = "sre-demo"
    namespace = kubernetes_namespace_v1.sre_practice.metadata[0].name
  }

  spec {
    selector = {
      app = "sre-demo"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}