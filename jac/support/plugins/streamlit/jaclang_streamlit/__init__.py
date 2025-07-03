"""Streamlit of Jac."""

from jaclang_streamlit.app_test import JacAppTest as AppTest

import typing

try:  # pragma: no cover - provide fallback for Python<3.12
    typing.override  # type: ignore[attr-defined]
except AttributeError:  # pragma: no cover
    from typing_extensions import override as _override

    typing.override = _override  # type: ignore[attr-defined]


def run_streamlit(basename: str, dirname: str) -> None:
    """Run the Streamlit application."""
    from jaclang.runtimelib.machine import JacMachineInterface

    JacMachineInterface.jac_import(
        basename, base_path=dirname, reload_module=True
    )  # TODO: need flag to force reload here


__all__ = ["AppTest", "run_streamlit"]
