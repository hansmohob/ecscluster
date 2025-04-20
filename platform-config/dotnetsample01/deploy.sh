# Get the image tag from SSM Parameter Store
IMAGE_TAG=$(aws ssm get-parameter --name "/${prefix_code}/image-tag" --query "Parameter.Value" --output text)

# Get ECR repository URLs from SSM Parameter Store
FRONTEND_REPO=$(aws ssm get-parameter --name "/${prefix_code}/ecr/frontend" --query "Parameter.Value" --output text)
ORDER_REPO=$(aws ssm get-parameter --name "/${prefix_code}/ecr/orderservice" --query "Parameter.Value" --output text)
PRODUCT_REPO=$(aws ssm get-parameter --name "/${prefix_code}/ecr/productapi" --query "Parameter.Value" --output text)
USER_REPO=$(aws ssm get-parameter --name "/${prefix_code}/ecr/userservice" --query "Parameter.Value" --output text)

# Replace placeholder values in deployment files
sed -i "s "s|PLACEHOLDER_FRONTEND_IMAGE|${FRONTEND_REPO}:${IMAGE_TAG}|g" frontend-deployment.yaml
sed -i "s|PLACEHOLDER_ORDERSERVICE_IMAGE|${ORDER_REPO}:${IMAGE_TAG}|g" orderservice-deployment.yaml
sed -i "s|PLACEHOLDER_PRODUCTAPI_IMAGE|${PRODUCT_REPO}:${IMAGE_TAG}|g" productapi-deployment.yaml
sed -i "s|PLACEHOLDER_USERSERVICE_IMAGE|${USER_REPO}:${IMAGE_TAG}|g" userservice-deployment.yaml