# CrashLoopBackOff Runbook

## Investigation

kubectl get pods -n sre-practice

kubectl describe pod <pod-name> \
  -n sre-practice

kubectl logs <pod-name> \
  -n sre-practice

kubectl logs <pod-name> \
  -n sre-practice \
  --previous

## Check

- Exit code
- Application startup errors
- Missing environment variables
- Missing configuration
- Probe failures
- OOMKilled
