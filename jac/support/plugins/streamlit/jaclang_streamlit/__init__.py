"""Streamlit of Jac."""

from jaclang_streamlit.test_app import JacAppTest as AppTest


def run_streamlit(basename: str, dirname: str) -> None:
    """Run the Streamlit application."""
    from jaclang.runtimelib.machine import JacMachineInterface

    JacMachineInterface.jac_import(
        basename, base_path=dirname, reload_module=True
    )  # TODO: need flag to force reload here


__all__ = ["AppTest", "run_streamlit"]
