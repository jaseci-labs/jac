"""Streamlit of Jac."""

from jaclang_streamlit.app_test import JacAppTest as AppTest
from jaclang.runtimelib.machine import plugin_manager


def run_streamlit(basename: str, dirname: str) -> None:
    """Run the Streamlit application."""
    import jaclang.runtimelib.machine as machine

    if "JacMachineInterfaceImpl" not in plugin_manager._name2plugin:
        plugin_manager.register(machine.JacMachineInterfaceImpl)

    machine.JacMachineInterface.jac_import(
        basename,
        base_path=dirname,
        reload_module=True
    )


__all__ = ["AppTest", "run_streamlit"]
