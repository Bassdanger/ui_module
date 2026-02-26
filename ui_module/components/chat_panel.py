"""Main chat panel: message history and user input."""

from __future__ import annotations

import streamlit as st

from ui_module.chat_client import invoke_agent


def render_chat_panel() -> None:
    """Render the conversation history and handle new user input."""
    if "messages" not in st.session_state:
        st.session_state["messages"] = []

    for msg in st.session_state["messages"]:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    if prompt := st.chat_input("Type your message…"):
        st.session_state["messages"].append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        with st.chat_message("assistant"):
            with st.spinner("Thinking…"):
                extra_kwargs = {}
                if "temperature" in st.session_state:
                    extra_kwargs["temperature"] = st.session_state["temperature"]
                if "system_prompt" in st.session_state:
                    extra_kwargs["system_prompt"] = st.session_state["system_prompt"]

                response = invoke_agent(
                    st.session_state["messages"],
                    **extra_kwargs,
                )
            st.markdown(response)

        st.session_state["messages"].append({"role": "assistant", "content": response})
