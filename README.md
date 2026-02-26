# Chat UI Module

Private Streamlit chatbot UI deployed on ECS Fargate in AWS private subnets, fronted by an internal ALB, and backed by a private API Gateway agent endpoint.

## Repository structure

```
├── ui_module/                  # Python Streamlit application
│   ├── app.py                  # Entry point
│   ├── config.py               # Environment-based configuration
│   ├── chat_client.py          # HTTP client for the agent invoke / sessions endpoints
│   └── components/
│       ├── chat_panel.py       # Conversation history and input
│       └── sidebar.py          # Session management and settings
├── Dockerfile                  # Container image for the Streamlit app
├── infra/chat_ui_ecs/          # Terraform module
│   ├── main.tf                 # ECS cluster, Fargate service, ALB, ECR, IAM, VPC endpoints
│   ├── variables.tf            # Module inputs
│   └── outputs.tf              # Module outputs
├── examples/basic/             # Example usage of the Terraform module
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── requirements.txt            # Python dependencies
```

## Prerequisites

- An existing AWS VPC with **two private subnets** (no public subnets required).
- **Podman** (aliased as `docker`) or Docker installed locally to build and push the container image.
- A **private API Gateway** endpoint for your agent (the module can create the `execute-api` VPC endpoint for you).
- Terraform >= 1.3 and AWS provider ~> 5.0.

## Quick start

### 1. Deploy the infrastructure

```bash
cd examples/basic
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your VPC, subnet, and API values
terraform init
terraform apply
```

This creates the ECR repository, ECS cluster, Fargate service, internal ALB, IAM roles, CloudWatch log group, and all required VPC endpoints.

### 2. Build and push the container image

```bash
# Get the ECR repo URL from Terraform output
ECR_URL=$(cd examples/basic && terraform output -raw ecr_repository_url)
REGISTRY=$(echo "$ECR_URL" | cut -d/ -f1)

# Authenticate with ECR (works with both Podman and Docker)
aws ecr get-login-password --region <region> | \
  podman login --username AWS --password-stdin "$REGISTRY"

# Build and push
podman build -t "$ECR_URL:latest" .
podman push "$ECR_URL:latest"
```

### 3. Deploy the new image

Force a new ECS deployment so the service pulls the latest image:

```bash
aws ecs update-service \
  --cluster $(cd examples/basic && terraform output -raw ecs_cluster_name) \
  --service $(cd examples/basic && terraform output -raw ecs_service_name) \
  --force-new-deployment \
  --region <region>
```

### 4. Access the UI

The internal ALB provides a **stable private DNS name** that does not change across deployments. Get it with:

```bash
cd examples/basic && terraform output -raw alb_dns_name
```

Because the ALB is internal and lives in private subnets, you must be **inside the VPC** (or connected to it) to reach it.

**Option A -- VPN / Direct Connect**

If your corporate network is connected to the VPC, open:

```
http://<alb-dns-name>
```

directly in your browser.

**Option B -- SSM port forwarding**

Forward through any SSM-enabled EC2 instance in the same VPC to the ALB:

```bash
aws ssm start-session \
  --target <instance-id-in-vpc> \
  --region <region> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"<alb-dns-name>\"],\"portNumber\":[\"80\"],\"localPortNumber\":[\"8501\"]}"
```

Then open **http://localhost:8501** in your browser.

**Option C -- From another instance in the VPC**

From any instance with a browser (WorkSpaces, AppStream, jump host), navigate to:

```
http://<alb-dns-name>
```

> **Note:** The private API Gateway is only reachable from inside the VPC. There is no way to access this UI from the public internet.

## Configuration

All runtime configuration is passed as environment variables to the container:

| Variable | Required | Default | Description |
|---|---|---|---|
| `AGENT_API_BASE_URL` | Yes | -- | Private API Gateway base URL |
| `AGENT_API_AUTH_MODE` | No | `none` | `iam`, `api_key`, or `none` |
| `AWS_DEFAULT_REGION` | No | `us-east-1` | AWS region (used for SigV4 signing) |
| `REQUEST_TIMEOUT_SECONDS` | No | `30` | HTTP timeout for agent calls |
| `AGENT_API_KEY` | If `api_key` | -- | API key value when using `api_key` auth |

The Terraform module sets `AGENT_API_BASE_URL`, `AGENT_API_AUTH_MODE`, and `AWS_DEFAULT_REGION` automatically from module variables.

## Terraform module inputs

See [`infra/chat_ui_ecs/variables.tf`](infra/chat_ui_ecs/variables.tf) for the full list. Key inputs:

| Input | Type | Required | Description |
|---|---|---|---|
| `vpc_id` | `string` | Yes | Existing VPC ID |
| `private_subnet_ids` | `list(string)` | Yes | Exactly 2 private subnet IDs |
| `vpc_cidrs` | `list(string)` | Yes | VPC CIDR blocks for ALB SG ingress |
| `region` | `string` | Yes | AWS region |
| `container_image` | `string` | No (default `""`) | Full image URI; empty = use module-created ECR repo |
| `task_cpu` | `number` | No (default `256`) | Fargate CPU units |
| `task_memory` | `number` | No (default `512`) | Fargate memory in MiB |
| `desired_count` | `number` | No (default `1`) | Number of Fargate tasks |
| `create_ecr_repository` | `bool` | No (default `true`) | Create an ECR repository |
| `create_execute_api_vpce` | `bool` | No (default `true`) | Create execute-api VPC endpoint |
| `create_s3_gateway_endpoint` | `bool` | No (default `true`) | Create S3 gateway endpoint for ECR pulls |

## Terraform module outputs

| Output | Description |
|---|---|
| `ecr_repository_url` | ECR repo URL for `podman push` |
| `alb_dns_name` | Stable private DNS for the UI |
| `ecs_cluster_name` | ECS cluster name |
| `ecs_service_name` | ECS service name |
| `task_security_group_id` | SG ID for Fargate tasks |
| `alb_security_group_id` | SG ID for the internal ALB |
| `execute_api_vpce_id` | Execute-api VPC endpoint ID |
