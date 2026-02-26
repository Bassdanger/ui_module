"""HTTP client for the agent invoke and sessions endpoints."""

from __future__ import annotations

import json
import logging
from typing import Any

import requests

from ui_module.config import config

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Auth helpers
# ---------------------------------------------------------------------------

def _get_base_headers() -> dict[str, str]:
    return {"Content-Type": "application/json"}


def _get_auth_headers(method: str, url: str) -> dict[str, str]:
    if config.agent_api_auth_mode == "iam":
        return _sign_request_iam(method, url)
    if config.agent_api_auth_mode == "api_key":
        import os
        return {"x-api-key": os.environ.get("AGENT_API_KEY", "")}
    return {}


def _sign_request_iam(method: str, url: str) -> dict[str, str]:
    try:
        import botocore.auth
        import botocore.awsrequest
        import botocore.session

        session = botocore.session.get_session()
        credentials = session.get_credentials().get_frozen_credentials()
        signer = botocore.auth.SigV4Auth(credentials, "execute-api", config.aws_region)

        aws_request = botocore.awsrequest.AWSRequest(
            method=method,
            url=url,
            headers={"Content-Type": "application/json"},
        )
        signer.add_auth(aws_request)
        return dict(aws_request.headers)
    except Exception:
        logger.exception("Failed to sign request with SigV4")
        return {}


def _request(method: str, path: str, body: dict | None = None) -> dict[str, Any]:
    """Generic request helper that handles auth, errors, and JSON parsing."""
    url = f"{config.agent_api_base_url}{path}"
    headers = _get_base_headers()
    headers.update(_get_auth_headers(method, url))

    kwargs: dict[str, Any] = {"headers": headers, "timeout": config.request_timeout}
    if body is not None:
        kwargs["data"] = json.dumps(body)

    resp = requests.request(method, url, **kwargs)
    resp.raise_for_status()
    return resp.json()


# ---------------------------------------------------------------------------
# Sessions API  —  /prod/sessions
# ---------------------------------------------------------------------------

def create_session() -> dict[str, Any]:
    """POST /prod/sessions — create a new session.

    Returns the session object (sessionId, createdAt, lastActive, messageCount).
    """
    try:
        return _request("POST", "/prod/sessions")
    except Exception:
        logger.exception("Failed to create session")
        return {}


def list_sessions() -> list[dict[str, Any]]:
    """GET /prod/sessions — list all sessions."""
    try:
        data = _request("GET", "/prod/sessions")
        if isinstance(data, list):
            return data
        return data.get("sessions", [])
    except Exception:
        logger.exception("Failed to list sessions")
        return []


def delete_session(session_id: str) -> bool:
    """DELETE /prod/sessions — delete a session by ID."""
    try:
        _request("DELETE", f"/prod/sessions/{session_id}")
        return True
    except Exception:
        logger.exception("Failed to delete session %s", session_id)
        return False


# ---------------------------------------------------------------------------
# Invoke API  —  /prod/invoke
# ---------------------------------------------------------------------------

def invoke_agent(
    messages: list[dict[str, str]],
    session_id: str | None = None,
    **kwargs: Any,
) -> str:
    """POST /prod/invoke — send a conversation to the agent.

    Parameters
    ----------
    messages:
        List of ``{"role": "user"|"assistant", "content": "..."}`` dicts.
    session_id:
        Active session ID to include in the request payload.
    **kwargs:
        Extra fields forwarded in the request body (e.g. temperature).

    Returns
    -------
    str
        The text content of the agent response.
    """
    payload: dict[str, Any] = {"messages": messages, **kwargs}
    if session_id:
        payload["sessionId"] = session_id

    try:
        body = _request("POST", "/prod/invoke", payload)
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
