"""Sidebar controls for the chatbot UI."""

from __future__ import annotations

import streamlit as st


def render_sidebar() -> None:
    """Render the sidebar with session controls and optional settings."""
    with st.sidebar:
        st.title("Chat Settings")

        if st.button("Clear conversation", use_container_width=True):
            st.session_state["messages"] = []
            st.rerun()

        st.divider()

        st.session_state["temperature"] = st.slider(
            "Temperature",
            min_value=0.0,
            max_value=1.0,
            value=st.session_state.get("temperature", 0.7),
            step=0.1,
        )

        st.session_state["system_prompt"] = st.text_area(
            "System prompt",
            value=st.session_state.get("system_prompt", "You are a helpful assistant."),
            height=120,
        )
