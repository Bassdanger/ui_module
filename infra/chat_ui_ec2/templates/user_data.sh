#!/bin/bash
set -euo pipefail

# Export environment variables for the Streamlit app
export AGENT_API_BASE_URL="${agent_api_base_url}"
export AGENT_API_AUTH_MODE="${agent_api_auth_mode}"
export AWS_DEFAULT_REGION="${aws_region}"
export STREAMLIT_SERVER_PORT="${ui_port}"
export STREAMLIT_SERVER_ADDRESS="0.0.0.0"
export STREAMLIT_SERVER_HEADLESS="true"

cat > /etc/profile.d/chat-ui-env.sh <<'ENVEOF'
export AGENT_API_BASE_URL="${agent_api_base_url}"
export AGENT_API_AUTH_MODE="${agent_api_auth_mode}"
export AWS_DEFAULT_REGION="${aws_region}"
ENVEOF

cd /opt/ui_module

nohup /usr/local/bin/streamlit run app.py \
  --server.port "${ui_port}" \
  --server.address 0.0.0.0 \
  --server.headless true \
  > /var/log/streamlit-ui.log 2>&1 &
