"""Sidebar: session management and chat settings."""

from __future__ import annotations

import streamlit as st

from ui_module.chat_client import create_session, delete_session, list_sessions


def _refresh_sessions() -> None:
    """Fetch sessions from the API and store in session state."""
    st.session_state["sessions"] = list_sessions()


def _switch_session(session_id: str) -> None:
    """Set the active session and clear local messages."""
    st.session_state["active_session_id"] = session_id
    st.session_state["messages"] = []


def render_sidebar() -> None:
    """Render the sidebar with session list and settings."""
    with st.sidebar:
        st.title("Sessions")

        if "sessions" not in st.session_state:
            _refresh_sessions()

        # --- New session ---
        if st.button("New session", use_container_width=True):
            new = create_session()
            if new and new.get("sessionId"):
                _refresh_sessions()
                _switch_session(new["sessionId"])
                st.rerun()
            else:
                st.error("Failed to create a new session.")

        # --- Session list ---
        sessions = st.session_state.get("sessions", [])
        active_id = st.session_state.get("active_session_id")

        if sessions:
            for sess in sessions:
                sid = sess.get("sessionId", "unknown")
                label = f"{sid[:8]}…  ({sess.get('messageCount', 0)} msgs)"
                col_select, col_delete = st.columns([4, 1])
                with col_select:
                    is_active = sid == active_id
                    if st.button(
                        label,
                        key=f"sel_{sid}",
                        use_container_width=True,
                        disabled=is_active,
                    ):
                        _switch_session(sid)
                        st.rerun()
                with col_delete:
                    if st.button("X", key=f"del_{sid}"):
                        delete_session(sid)
                        if sid == active_id:
                            st.session_state.pop("active_session_id", None)
                            st.session_state["messages"] = []
                        _refresh_sessions()
                        st.rerun()
        else:
            st.caption("No sessions yet.")

        if st.button("Refresh", use_container_width=True):
            _refresh_sessions()
            st.rerun()

        # --- Settings ---
        st.divider()
        st.subheader("Settings")

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
