"""Thin HTTP client for the agent invoke endpoint."""

from __future__ import annotations

import json
import logging
from typing import Any

import requests

from ui_module.config import config

logger = logging.getLogger(__name__)


def _get_auth_headers() -> dict[str, str]:
    """Return auth headers based on the configured auth mode."""
    if config.agent_api_auth_mode == "iam":
        return _sign_request_iam()
    if config.agent_api_auth_mode == "api_key":
        import os

        api_key = os.environ.get("AGENT_API_KEY", "")
        return {"x-api-key": api_key}
    return {}


def _sign_request_iam() -> dict[str, str]:
    """Build SigV4-signed headers for IAM-authenticated API Gateway calls."""
    try:
        import botocore.auth
        import botocore.awsrequest
        import botocore.session

        session = botocore.session.get_session()
        credentials = session.get_credentials().get_frozen_credentials()
        signer = botocore.auth.SigV4Auth(credentials, "execute-api", config.aws_region)

        request = botocore.awsrequest.AWSRequest(
            method="POST",
            url=f"{config.agent_api_base_url}/invoke",
            headers={"Content-Type": "application/json"},
        )
        signer.add_auth(request)
        return dict(request.headers)
    except Exception:
        logger.exception("Failed to sign request with SigV4")
        return {}


def invoke_agent(messages: list[dict[str, str]], **kwargs: Any) -> str:
    """Send a conversation to the agent and return the assistant reply.

    Parameters
    ----------
    messages:
        List of ``{"role": "user"|"assistant", "content": "..."}`` dicts.
    **kwargs:
        Extra fields forwarded in the request body (e.g. temperature, model).

    Returns
    -------
    str
        The text content of the agent response.
    """
    url = f"{config.agent_api_base_url}/invoke"
    headers = {"Content-Type": "application/json"}
    headers.update(_get_auth_headers())

    payload: dict[str, Any] = {"messages": messages, **kwargs}

    try:
        resp = requests.post(
            url,
            headers=headers,
            data=json.dumps(payload),
            timeout=config.request_timeout,
        )
        resp.raise_for_status()
        body = resp.json()
        return body.get("output", body.get("response", json.dumps(body)))
    except requests.exceptions.Timeout:
        logger.warning("Agent request timed out after %ss", config.request_timeout)
        return "The agent did not respond in time. Please try again."
    except requests.exceptions.ConnectionError:
        logger.exception("Connection error reaching agent endpoint")
        return "Unable to reach the agent service. Check your network configuration."
    except Exception:
        logger.exception("Unexpected error calling agent")
        return "An unexpected error occurred. Please try again."
