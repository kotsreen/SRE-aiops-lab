variable "kubeconfig_path" {
  description = "Path to Kubernetes kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "monitoring_namespace" {
  description = "Namespace for Prometheus, Grafana and Alertmanager"
  type        = string
  default     = "monitoring"
}

variable "monitoring_release_name" {
  description = "Helm release name for kube-prometheus-stack"
  type        = string
  default     = "monitoring"
}
variable "ollama_model" {
  description = "Local Ollama model used for incident analysis"
  type        = string
  default     = "qwen3:4b"
}
