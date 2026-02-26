"""Streamlit chatbot UI — main entry point.

Run with:
    streamlit run ui_module/app.py --server.port 8501 --server.address 0.0.0.0
"""

from __future__ import annotations

import streamlit as st

from ui_module.config import config
from ui_module.components.chat_panel import render_chat_panel
from ui_module.components.sidebar import render_sidebar

config.validate()

st.set_page_config(page_title="Chat UI", page_icon="💬", layout="wide")
st.title("Agent Chat")

render_sidebar()
render_chat_panel()
