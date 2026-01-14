#!/bin/bash

# Check if a namespace is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <namespace>"
  exit 1
fi

NAMESPACE=$1

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed."
    exit 1
fi

echo "Looking for deployments with pods in CrashLoopBackOff in namespace '$NAMESPACE'..."

# Get pods in CrashLoopBackOff
# We search for lines containing "CrashLoopBackOff" and grab the first column (Pod name)
CRASHING_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep "CrashLoopBackOff" | awk '{print $1}')

if [ -z "$CRASHING_PODS" ]; then
  echo "No pods found in CrashLoopBackOff state in namespace '$NAMESPACE'."
  exit 0
fi

# Use an associative array to deduplicate deployment names
declare -A DEPLOYMENTS_TO_SCALE

echo "Found crashing pods. Identifying their deployments..."

for POD in $CRASHING_PODS; do
  # Get the immediate owner of the pod (usually a ReplicaSet)
  OWNER_DATA=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.metadata.ownerReferences[0].kind} {.metadata.ownerReferences[0].name}')
  read -r OWNER_KIND OWNER_NAME <<< "$OWNER_DATA"

  DEPLOYMENT_NAME=""

  if [ "$OWNER_KIND" == "ReplicaSet" ]; then
    # Get the owner of the ReplicaSet (usually a Deployment)
    RS_OWNER_DATA=$(kubectl get rs "$OWNER_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.ownerReferences[0].kind} {.metadata.ownerReferences[0].name}')
    read -r RS_OWNER_KIND RS_OWNER_NAME <<< "$RS_OWNER_DATA"

    if [ "$RS_OWNER_KIND" == "Deployment" ]; then
      DEPLOYMENT_NAME="$RS_OWNER_NAME"
    fi
  elif [ "$OWNER_KIND" == "Deployment" ]; then
    # Direct deployment ownership (rare but possible in some configs)
    DEPLOYMENT_NAME="$OWNER_NAME"
  fi

  if [ -n "$DEPLOYMENT_NAME" ]; then
    DEPLOYMENTS_TO_SCALE["$DEPLOYMENT_NAME"]=1
  fi
done

if [ ${#DEPLOYMENTS_TO_SCALE[@]} -eq 0 ]; then
  echo "Found crashing pods, but could not identify any owning Deployments."
  exit 0
fi

# Scale the identified deployments
for DEPLOYMENT in "${!DEPLOYMENTS_TO_SCALE[@]}"; do
  echo "Scaling deployment '$DEPLOYMENT' to 0..."
  kubectl scale deployment "$DEPLOYMENT" --replicas=0 -n "$NAMESPACE"
done

echo "Done."
