#!/bin/bash
set -euo pipefail

exec > /var/log/user-data.log 2>&1

# ---------- Download application code from S3 (if configured) ----------------

APP_S3_URI="${app_s3_uri}"

if [ -n "$APP_S3_URI" ]; then
  echo "Downloading application artifact from $APP_S3_URI ..."
  mkdir -p /opt/ui_module
  ARTIFACT="/tmp/ui_module_artifact.tar.gz"
  aws s3 cp "$APP_S3_URI" "$ARTIFACT" --region "${aws_region}"
  tar -xzf "$ARTIFACT" -C /opt/ui_module --strip-components=1
  rm -f "$ARTIFACT"

  if [ -f /opt/ui_module/requirements.txt ]; then
    pip3 install --no-cache-dir -r /opt/ui_module/requirements.txt
  fi
fi

# ---------- Export environment variables for the Streamlit app ----------------

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

# ---------- Start Streamlit ---------------------------------------------------

cd /opt/ui_module

nohup /usr/local/bin/streamlit run app.py \
  --server.port "${ui_port}" \
  --server.address 0.0.0.0 \
  --server.headless true \
  > /var/log/streamlit-ui.log 2>&1 &
