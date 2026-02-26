# Chat UI Module

Private Streamlit chatbot UI deployed on EC2 in AWS private subnets, backed by a private API Gateway agent endpoint.

## Repository structure

```
├── ui_module/                  # Python Streamlit application
│   ├── app.py                  # Entry point
│   ├── config.py               # Environment-based configuration
│   ├── chat_client.py          # HTTP client for the agent invoke endpoint
│   └── components/
│       ├── chat_panel.py       # Conversation history and input
│       └── sidebar.py          # Settings controls
├── infra/chat_ui_ec2/          # Terraform module
│   ├── main.tf                 # EC2 ASG, SGs, VPC endpoints
│   ├── variables.tf            # Module inputs
│   ├── outputs.tf              # Module outputs
│   └── templates/
│       └── user_data.sh        # EC2 bootstrap script
├── examples/basic/             # Example usage of the Terraform module
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── requirements.txt            # Python dependencies
```

## Prerequisites

- An existing AWS VPC with **two private subnets** (no public subnets required).
- A **custom RHEL AMI** with Python, Streamlit, and this `ui_module` package installed at `/opt/ui_module`.
- A **private API Gateway** endpoint for your agent (the module can create the `execute-api` VPC endpoint for you).
- Terraform >= 1.3 and AWS provider ~> 5.0.

## Quick start

### 1. Deploy the infrastructure

```bash
cd examples/basic
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your VPC, subnet, AMI, and API values
terraform init
terraform apply
```

### 2. Verify the deployment

The EC2 instance created by this module runs in a private subnet and starts
Streamlit automatically via user data. To troubleshoot or manually restart
the app, connect to the deployed instance using SSM Session Manager
(no public IP or bastion host required):

```bash
aws ssm start-session --target <instance-id> --region <region>
```

Once connected:

```bash
# Check if Streamlit is running
ps aux | grep streamlit

# View logs
tail -f /var/log/streamlit-ui.log

# Restart manually if needed
cd /opt/ui_module
streamlit run app.py --server.port 8501 --server.address 0.0.0.0
```

### 3. Access the UI

The Streamlit UI listens on port **8501** on the EC2 instance's private IP.
Because everything runs in private subnets, you must be **inside the VPC**
(or connected to it) to open the UI in a browser.

**Option A — SSM port forwarding (simplest, no VPN required)**

Forward the remote Streamlit port to your local machine through SSM:

```bash
aws ssm start-session \
  --target <instance-id> \
  --region <region> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8501"],"localPortNumber":["8501"]}'
```

Then open **http://localhost:8501** in your browser.

**Option B — From another instance in the VPC**

If you have a desktop or jump host inside the VPC with a browser (e.g. an
Amazon WorkSpaces instance, AppStream, or an EC2 with a GUI), navigate
directly to:

```
http://<ec2-private-ip>:8501
```

**Option C — VPN / Direct Connect**

If your corporate network is connected to the VPC via Site-to-Site VPN or
Direct Connect, open `http://<ec2-private-ip>:8501` from any machine on
your corporate network (ensure the VPN routes and security groups allow it).

> **Note:** The private API Gateway is only reachable from inside the VPC.
> There is no way to run this UI from the public internet.

## Configuration

All runtime configuration is via environment variables:

| Variable | Required | Default | Description |
|---|---|---|---|
| `AGENT_API_BASE_URL` | Yes | — | Private API Gateway base URL |
| `AGENT_API_AUTH_MODE` | No | `none` | `iam`, `api_key`, or `none` |
| `AWS_DEFAULT_REGION` | No | `us-east-1` | AWS region (used for SigV4 signing) |
| `REQUEST_TIMEOUT_SECONDS` | No | `30` | HTTP timeout for agent calls |
| `AGENT_API_KEY` | If `api_key` | — | API key value when using `api_key` auth |

## Terraform module inputs

See [`infra/chat_ui_ec2/variables.tf`](infra/chat_ui_ec2/variables.tf) for the full list. Key inputs:

| Input | Type | Required | Description |
|---|---|---|---|
| `vpc_id` | `string` | Yes | Existing VPC ID |
| `private_subnet_ids` | `list(string)` | Yes | Exactly 2 private subnet IDs |
| `ami_id` | `string` | Yes | Custom RHEL AMI ID |
| `region` | `string` | Yes | AWS region |
| `create_execute_api_vpce` | `bool` | No (default `true`) | Create execute-api VPC endpoint |
