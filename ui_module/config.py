"""Application configuration loaded from environment variables."""

import os
import sys


class Config:
    """Immutable runtime configuration derived from environment variables."""

    def __init__(self) -> None:
        self.agent_api_base_url: str = os.environ.get("AGENT_API_BASE_URL", "")
        self.agent_api_auth_mode: str = os.environ.get("AGENT_API_AUTH_MODE", "none")
        self.aws_region: str = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
        self.request_timeout: int = int(os.environ.get("REQUEST_TIMEOUT_SECONDS", "30"))
        self.log_level: str = os.environ.get("LOG_LEVEL", "INFO")

    def validate(self) -> None:
        errors: list[str] = []
        if not self.agent_api_base_url:
            errors.append("AGENT_API_BASE_URL is not set")
        if self.agent_api_auth_mode not in ("iam", "api_key", "none"):
            errors.append(
                f"AGENT_API_AUTH_MODE must be iam, api_key, or none; got '{self.agent_api_auth_mode}'"
            )
        if errors:
            for err in errors:
                print(f"[config] ERROR: {err}", file=sys.stderr)
            raise SystemExit(1)


config = Config()
