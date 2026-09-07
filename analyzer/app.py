from fastapi import FastAPI, Request
from kubernetes import client, config
from datetime import datetime, timezone
import requests
import os
import json
import time

app = FastAPI()

NAMESPACE = os.getenv("NAMESPACE", "sre-practice")
APPLICATION = "sre-demo"
CONTAINER = "nginx"

GOOD_IMAGE = "nginx:alpine"
BAD_IMAGE = "nginx:intentional-invalid-sre-image"

OLLAMA_URL = os.getenv(
    "OLLAMA_URL",
    "http://host.docker.internal:11434"
)

OLLAMA_MODEL = os.getenv(
    "OLLAMA_MODEL",
    "qwen3:4b"
)

SUMMARY_CONFIGMAP = "incident-summary"

config.load_incluster_config()

core = client.CoreV1Api()
apps = client.AppsV1Api()


# ---------------------------------------------------------
# Health
# ---------------------------------------------------------

@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "incident-analyzer"
    }


# ---------------------------------------------------------
# Kubernetes context
# ---------------------------------------------------------

def collect_context():

    pods = []

    pod_list = core.list_namespaced_pod(
        namespace=NAMESPACE
    )

    for pod in pod_list.items:

        containers = []

        for status in pod.status.container_statuses or []:

            waiting_reason = None

            if status.state and status.state.waiting:
                waiting_reason = status.state.waiting.reason

            containers.append({
                "name": status.name,
                "ready": status.ready,
                "restart_count": status.restart_count,
                "waiting_reason": waiting_reason
            })

        pods.append({
            "name": pod.metadata.name,
            "phase": pod.status.phase,
            "containers": containers
        })

    events = []

    event_list = core.list_namespaced_event(
        namespace=NAMESPACE
    )

    for event in event_list.items[-30:]:

        events.append({
            "reason": event.reason,
            "type": event.type,
            "message": event.message
        })

    deployments = []

    deployment_list = apps.list_namespaced_deployment(
        namespace=NAMESPACE
    )

    for deployment in deployment_list.items:

        deployments.append({
            "name": deployment.metadata.name,
            "desired_replicas": deployment.spec.replicas,
            "available_replicas":
                deployment.status.available_replicas or 0,
            "images": [
                container.image
                for container
                in deployment.spec.template.spec.containers
            ]
        })

    return {
        "pods": pods,
        "events": events,
        "deployments": deployments
    }


# ---------------------------------------------------------
# Runbook
# ---------------------------------------------------------

def read_runbook():

    path = "/runbooks/imagepullbackoff.md"

    try:
        with open(path, "r") as file:
            return file.read()

    except Exception as exc:
        return f"Runbook unavailable: {exc}"


# ---------------------------------------------------------
# Incident creation
# ---------------------------------------------------------

def create_imagepullbackoff():

    patch = {
        "spec": {
            "template": {
                "spec": {
                    "containers": [
                        {
                            "name": CONTAINER,
                            "image": BAD_IMAGE
                        }
                    ]
                }
            }
        }
    }

    apps.patch_namespaced_deployment(
        name=APPLICATION,
        namespace=NAMESPACE,
        body=patch
    )

    return {
        "application": APPLICATION,
        "image": BAD_IMAGE,
        "action": "fault injected"
    }


# ---------------------------------------------------------
# Wait for Kubernetes failure
# ---------------------------------------------------------

def wait_for_image_failure(timeout=45):

    end_time = time.time() + timeout

    while time.time() < end_time:

        context = collect_context()

        for pod in context["pods"]:

            for container in pod["containers"]:

                reason = container.get(
                    "waiting_reason"
                )

                if reason in [
                    "ImagePullBackOff",
                    "ErrImagePull"
                ]:
                    return context

        time.sleep(3)

    return collect_context()


# ---------------------------------------------------------
# Determine incident state
# ---------------------------------------------------------

def determine_status(context):

    for pod in context["pods"]:

        for container in pod["containers"]:

            if container.get("waiting_reason") in [
                "ImagePullBackOff",
                "ErrImagePull"
            ]:
                return "FIRING"

    return "NOT_FIRING"


# ---------------------------------------------------------
# Collect useful evidence
# ---------------------------------------------------------

def extract_evidence(context):

    evidence = []

    for pod in context["pods"]:

        for container in pod["containers"]:

            reason = container.get(
                "waiting_reason"
            )

            if reason:

                evidence.append(
                    f'Pod {pod["name"]}: {reason}'
                )

    for event in context["events"]:

        reason = event.get("reason", "")

        if reason in [
            "Failed",
            "BackOff",
            "FailedToRetrieveImagePullSecret"
        ]:

            evidence.append(
                f'{reason}: {event.get("message", "")}'
            )

    return evidence[-10:]


# ---------------------------------------------------------
# Qwen incident analysis
# ---------------------------------------------------------

def analyze_with_qwen(context):

    runbook = read_runbook()

    prompt = f"""
You are a senior Site Reliability Engineer.

This is a controlled Kubernetes SRE laboratory.

INCIDENT TYPE:
ImagePullBackOff

APPLICATION:
{APPLICATION}

NAMESPACE:
{NAMESPACE}

KUBERNETES CONTEXT:

{json.dumps(context, indent=2)}

CURRENT RUNBOOK:

{runbook}

Analyze the incident.

Return:

ROOT CAUSE

EVIDENCE

SERVICE IMPACT

RECOMMENDED REMEDIATION

RECOVERY VALIDATION

PREVENTION

RUNBOOK GAPS

PROPOSED RUNBOOK UPDATE

CONFIDENCE

Only use evidence provided.

Do not execute commands.
Do not modify Kubernetes.
"""

    response = requests.post(
        f"{OLLAMA_URL}/api/chat",
        json={
            "model": OLLAMA_MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "stream": False
        },
        timeout=180
    )

    response.raise_for_status()

    return response.json()["message"]["content"]


# ---------------------------------------------------------
# Save incident summary
# ---------------------------------------------------------

def save_summary(summary):

    config_map = core.read_namespaced_config_map(
        name=SUMMARY_CONFIGMAP,
        namespace=NAMESPACE
    )

    config_map.data["summary.json"] = json.dumps(
        summary,
        indent=2
    )

    core.patch_namespaced_config_map(
        name=SUMMARY_CONFIGMAP,
        namespace=NAMESPACE,
        body=config_map
    )


# ---------------------------------------------------------
# Read incident summary
# ---------------------------------------------------------

def read_summary():

    config_map = core.read_namespaced_config_map(
        name=SUMMARY_CONFIGMAP,
        namespace=NAMESPACE
    )

    raw = config_map.data.get(
        "summary.json",
        "{}"
    )

    return json.loads(raw)


# ---------------------------------------------------------
# Create / refresh summary
# ---------------------------------------------------------

def build_summary(
    context,
    incident_id=None,
    start_time=None
):

    status = determine_status(context)
    evidence = extract_evidence(context)

    analysis = analyze_with_qwen(
        context
    )

    if incident_id is None:

        existing = read_summary()

        incident_id = existing.get(
            "incident_id",
            ""
        )

        start_time = existing.get(
            "start_time",
            ""
        )

    summary = {
        "incident_id": incident_id,
        "incident_type": "ImagePullBackOff",
        "application": APPLICATION,
        "namespace": NAMESPACE,
        "start_time": start_time,
        "last_updated":
            datetime.now(timezone.utc).isoformat(),
        "status": status,
        "evidence": evidence,
        "recommended_recovery":
            "Restore nginx:alpine using Terraform.",
        "qwen_analysis": analysis
    }

    save_summary(summary)

    return summary


# ---------------------------------------------------------
# Chat
# ---------------------------------------------------------

@app.post("/chat")
async def chat(request: Request):

    payload = await request.json()

    message = payload.get(
        "message",
        ""
    ).strip()

    message_lower = message.lower()

    # ---------------------------------------------
    # CREATE INCIDENT
    # ---------------------------------------------

    create_requested = (
        "create" in message_lower
        or "inject" in message_lower
        or "simulate" in message_lower
    )

    image_incident = (
        "imagepullbackoff" in message_lower
        or "image pull" in message_lower
    )

    if create_requested and image_incident:

        start_time = (
            datetime.now(timezone.utc)
            .isoformat()
        )

        incident_id = (
            "INC-"
            + datetime.now(timezone.utc)
            .strftime("%Y%m%d-%H%M%S")
        )

        create_imagepullbackoff()

        context = wait_for_image_failure()

        summary = build_summary(
            context=context,
            incident_id=incident_id,
            start_time=start_time
        )

        return {
            "message":
                "ImagePullBackOff incident created.",
            "summary": summary
        }

    # ---------------------------------------------
    # UPDATE / SHOW STATUS
    # ---------------------------------------------

    if (
        "status" in message_lower
        or "summary" in message_lower
        or "update" in message_lower
    ):

        context = collect_context()

        summary = build_summary(
            context=context
        )

        return {
            "message":
                "Incident summary updated.",
            "summary": summary
        }

    return {
        "message":
            "Supported commands: "
            "'Create an ImagePullBackOff incident and update the problem summary' "
            "or 'Update the incident summary'."
    }


# ---------------------------------------------------------
# Retrieve summary
# ---------------------------------------------------------

@app.get("/incident-summary")
def incident_summary():

    return read_summary()


# ---------------------------------------------------------
# Alertmanager webhook
# ---------------------------------------------------------

@app.post("/alert")
async def alert(request: Request):

    payload = await request.json()

    context = collect_context()

    summary = build_summary(
        context=context
    )

    print(
        "\n===== ALERTMANAGER ALERT ====="
    )

    print(
        json.dumps(
            payload,
            indent=2
        )
    )

    print(
        "\n===== INCIDENT SUMMARY ====="
    )

    print(
        json.dumps(
            summary,
            indent=2
        )
    )

    return {
        "status": "analyzed",
        "summary": summary
    }
