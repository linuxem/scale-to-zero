#!/bin/bash

# Check arguments
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <namespace> <recipient_email> <sender_email> [aws_region]"
    echo "Example: $0 my-app devops@example.com alerts@example.com us-east-1"
    exit 1
fi

NAMESPACE=$1
RECIPIENT=$2
SENDER=$3
AWS_REGION=${4:-il-central-1}

# Dependencies check
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed."
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "Error: aws cli is not installed."
    exit 1
fi

echo "Checking for CrashLoopBackOff pods in namespace '$NAMESPACE'..."

# Find pods in CrashLoopBackOff state
# capturing Pod Name and the specific Error Message if possible
PODS_LIST=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep "CrashLoopBackOff" | awk '{print $1}')

if [ -z "$PODS_LIST" ]; then
    echo "No pods in CrashLoopBackOff state found. No email sent."
    exit 0
fi

# Prepare Email Content
SUBJECT="Alert: CrashLoopBackOff detected in $NAMESPACE"
BODY="The following pods in namespace '$NAMESPACE' are in CrashLoopBackOff state:\n\n$PODS_LIST\n\nPlease investigate immediately."

echo "Found crashing pods. Sending email via AWS SES..."

# Send email using AWS SES
aws ses send-email \
    --from "$SENDER" \
    --destination "ToAddresses=$RECIPIENT" \
    --message "Subject={Data=$SUBJECT,Charset=utf-8},Body={Text={Data=$BODY,Charset=utf-8}}" \
    --region "$AWS_REGION"

if [ $? -eq 0 ]; then
    echo "Notification email sent successfully to $RECIPIENT."
else
    echo "Failed to send email. Ensure AWS SES is configured and '$SENDER' is a verified identity."
    exit 1
fi
