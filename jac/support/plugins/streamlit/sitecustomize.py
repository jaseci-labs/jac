import typing
from typing_extensions import override as _override

if not hasattr(typing, "override"):
    typing.override = _override  # type: ignore[attr-defined]

try:
    from jaclang.runtimelib.machine import plugin_manager
    from jaclang_streamlit.commands import JacCmd

    if "streamlit" not in plugin_manager.get_plugins():  # pragma: no cover
        plugin_manager.register(JacCmd, name="streamlit")
except Exception:  # pragma: no cover - ignore failures during early import
    pass
