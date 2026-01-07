#!/usr/bin/env bash

JENKINS_URL="http://ci.zabbix.lan"
VALID_JOBS=("frontend-phpunit" "frontend" "api" "syntax-check")
USER="$JENKINS_USER"
API_TOKEN="$JENKINS_TOKEN"

JOB_NAME="$1"
BRANCH_NAME="$2"

# Validate input
if [[ -z "$JOB_NAME" || -z "$BRANCH_NAME" ]]; then
  echo "Usage: $0 <job-name> <branch-name>"
  exit 1
fi

if [[ ! " ${VALID_JOBS[@]} " =~ " ${JOB_NAME} " ]]; then
  echo "Invalid job name. Must be one of: ${VALID_JOBS[*]}"
  exit 1
fi

# Get Jenkins crumb for CSRF protection
CRUMB=$(curl -s --user "$USER:$API_TOKEN" "$JENKINS_URL/crumbIssuer/api/json" | jq -r .crumb)

# Trigger the job
RESPONSE=$(curl -s -X POST "$JENKINS_URL/job/zabbix-dev/job/$JOB_NAME/buildWithParameters" \
  --user "$USER:$API_TOKEN" \
  -H "Jenkins-Crumb:$CRUMB" \
  --data-urlencode "BRANCH=$BRANCH_NAME" \
  -i)

# Extract queue URL
QUEUE_URL=$(echo "$RESPONSE" | grep -i Location | awk '{print $2}' | tr -d '\r\n')

if [ -z "$QUEUE_URL" ]; then
  echo "Failed to trigger job."
  exit 1
fi

echo "Job queued at: $QUEUE_URL"

# Poll the queue to get the job ID
while true; do
  JOB_INFO=$(curl -s --user "$USER:$API_TOKEN" "${QUEUE_URL}api/json")
  JOB_ID=$(echo "$JOB_INFO" | jq -r '.executable.number // empty')

  if [ -n "$JOB_ID" ]; then
    echo "Job started with ID: $JOB_ID"
    break
  fi
  echo "Waiting for job to start..."
  sleep 2
done


# Output badge markdown
ENCODED_JOB="zabbix-dev%2F$JOB_NAME"
BADGE="[!https://ci.zabbix.lan/buildStatus/icon?job=$ENCODED_JOB&amp;build=$JOB_ID!|https://ci.zabbix.lan/job/zabbix-dev/job/$JOB_NAME/$JOB_ID/]"

echo "- $JOB_NAME $BADGE"
