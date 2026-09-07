resource "helm_release" "kube_prometheus_stack" {

  name      = "monitoring"
  namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"

  create_namespace = false

  wait    = true
  timeout = 900

  values = [
    yamlencode({

      grafana = {
        enabled = true
      }

      prometheus = {
        enabled = true
      }

      alertmanager = {
        enabled = true

        config = {

          global = {
            resolve_timeout = "5m"
          }

          route = {

            receiver = "null"

            group_by = [
              "alertname",
              "namespace"
            ]

            group_wait      = "10s"
            group_interval  = "30s"
            repeat_interval = "30m"

            routes = [
              {
                receiver = "aiops-webhook"

                matchers = [
                  "team=\"sre-aiops\""
                ]
              }
            ]
          }

          receivers = [

            {
              name = "null"
            },

            {
              name = "aiops-webhook"

              webhook_configs = [
                {
                  url = "http://incident-analyzer.sre-practice.svc.cluster.local:8000/alert"

                  send_resolved = true
                }
              ]
            }
          ]
        }
      }

      additionalPrometheusRulesMap = {

        imagepullbackoff = yamldecode(
          file(
            "${path.module}/../alerts/imagepullbackoff.yaml"
          )
        )

        crashloopbackoff = yamldecode(
          file(
            "${path.module}/../alerts/crashloopbackoff.yaml"
          )
        )

        highcpu = yamldecode(
          file(
            "${path.module}/../alerts/cpu-high.yaml"
          )
        )

        slo = yamldecode(
          file(
            "${path.module}/../alerts/slo-burn-rate.yaml"
          )
        )
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    kubernetes_service_v1.incident_analyzer
  ]
}
