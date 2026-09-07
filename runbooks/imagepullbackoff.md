# ImagePullBackOff Runbook

## Detection

A container is unable to pull its configured image.

## Investigation

kubectl get pods -n sre-practice

kubectl get events \
  -n sre-practice \
  --sort-by='.lastTimestamp'

kubectl describe pod <pod-name> \
  -n sre-practice

kubectl get deployment sre-demo \
  -n sre-practice \
  -o jsonpath='{.spec.template.spec.containers[*].image}'

## Recovery

Restore the correct image through Terraform.

terraform plan
terraform apply

## Validation

kubectl rollout status deployment/sre-demo \
  -n sre-practice

kubectl get pods -n sre-practice
