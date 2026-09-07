# High CPU Runbook

## Investigation

kubectl top pods -n sre-practice

kubectl describe pod <pod-name> \
  -n sre-practice

kubectl get deployment sre-demo \
  -n sre-practice \
  -o yaml

## Check

- CPU utilization
- CPU request
- CPU limit
- CPU throttling
- Traffic increase
- Application loops
- HPA configuration
