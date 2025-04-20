#!/bin/bash

# Get the image tag from SSM Parameter Store
IMAGE_TAG=$(aws ssm get-parameter --name "/msn/ecr/image-tag" --query "Parameter.Value" --output text)

# Get ECR repository URL from SSM Parameter Store
OBSERVABILITY_REPO=$(aws ssm get-parameter --name "/msn/ecr/observability" --query "Parameter.Value" --output text)

# Replace placeholder value in deployment file
sed -i "s|PLACEHOLDER_OBSERVABILITY_IMAGE|${OBSERVABILITY_REPO}:${IMAGE_TAG}|g" k8s/deployment.yaml

# Apply the kubernetes manifests
kubectl apply -f k8s/