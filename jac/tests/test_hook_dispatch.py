# ruff: noqa: ANN401, N806
"""Hermetic behavior tests for the JacRuntime hook-dispatch proxy.

These pin that @hookable methods on ``JacRuntime`` route through the plugin
manager with correct keyword reconstruction and firstresult precedence — without
requiring the LLVM shim or product-tier .jac compilation.
"""

from __future__ import annotations

from types import SimpleNamespace
from typing import Any

import pytest


def _runtime() -> tuple[Any, Any, Any]:
    """Import runtime symbols lazily (after hermetic bootstrap fixture runs)."""
    from jaclang.jac0core.runtime import JacRuntime as Jac
    from jaclang.jac0core.runtime import hookimpl, plugin_manager

    return Jac, plugin_manager, hookimpl


def _make_core_stub(hookimpl: Any) -> type:
    class _CoreStubHooks:
        @staticmethod
        @hookimpl
        def store(
            base_path: str = "./storage", create_dirs: bool = True
        ) -> dict[str, Any]:
            return {
                "tier": "core",
                "base_path": base_path,
                "create_dirs": create_dirs,
            }

        @staticmethod
        @hookimpl
        def create_j_context(
            user_root: str | None,
            base_path_dir: str | None = None,
            full_target_path: str | None = None,
        ) -> SimpleNamespace:
            return SimpleNamespace(
                tier="core",
                user_root=user_root,
                base_path_dir=base_path_dir,
                full_target_path=full_target_path,
            )

        @staticmethod
        @hookimpl
        def get_sv_registry() -> dict[str, str]:
            return {"core-svc": "http://127.0.0.1:8000"}

        @staticmethod
        @hookimpl
        def get_api_server_class() -> type:
            return type("CoreAPIServer", (), {})

        @staticmethod
        @hookimpl
        def create_server(jac_server: object, host: str, port: int) -> object:
            return SimpleNamespace(tier="core", host=host, port=port)

        @staticmethod
        @hookimpl
        def sv_service_call(module_name: str, func_name: str, args: dict) -> Any:
            return {
                "tier": "core",
                "module": module_name,
                "func": func_name,
                "args": args,
            }

        @staticmethod
        @hookimpl
        def sv_walker_call(
            module_name: str, walker_name: str, args: dict, stub_cls: Any
        ) -> Any:
            return {
                "tier": "core",
                "module": module_name,
                "walker": walker_name,
                "args": args,
            }

    return _CoreStubHooks


def _make_scale_stub(hookimpl: Any) -> type:
    class _ScaleStubHooks:
        @staticmethod
        @hookimpl
        def store(
            base_path: str = "./storage", create_dirs: bool = True
        ) -> dict[str, Any]:
            return {
                "tier": "scale",
                "base_path": base_path,
                "create_dirs": create_dirs,
            }

        @staticmethod
        @hookimpl
        def get_sv_registry() -> dict[str, str]:
            return {"scale-svc": "http://scale.local:9000"}

        @staticmethod
        @hookimpl
        def get_api_server_class() -> type:
            return type("ScaleAPIServer", (), {})

        @staticmethod
        @hookimpl
        def sv_service_call(module_name: str, func_name: str, args: dict) -> Any:
            return {"tier": "scale", "module": module_name, "func": func_name}

    return _ScaleStubHooks


def _make_declining_scale_stub(hookimpl: Any) -> type:
    class _DecliningScaleStub:
        @staticmethod
        @hookimpl
        def store(
            base_path: str = "./storage", create_dirs: bool = True
        ) -> dict[str, Any] | None:
            return None

        @staticmethod
        @hookimpl
        def get_sv_registry() -> dict[str, str] | None:
            return None

        @staticmethod
        @hookimpl
        def get_api_server_class() -> type | None:
            return None

    return _DecliningScaleStub


@pytest.fixture
def core_stub_hooks(hermetic_hook_env: None) -> None:
    _, plugin_manager, hookimpl = _runtime()
    stub = _make_core_stub(hookimpl)
    plugin_manager.register(stub)
    yield
    plugin_manager.unregister(plugin=stub)


@pytest.fixture
def scale_stub_hooks(core_stub_hooks: None) -> None:
    _, plugin_manager, hookimpl = _runtime()
    stub = _make_scale_stub(hookimpl)
    plugin_manager.register(stub)
    yield
    plugin_manager.unregister(plugin=stub)


@pytest.fixture
def declining_scale_stub(core_stub_hooks: None) -> None:
    _, plugin_manager, hookimpl = _runtime()
    stub = _make_declining_scale_stub(hookimpl)
    plugin_manager.register(stub)
    yield
    plugin_manager.unregister(plugin=stub)


@pytest.mark.parametrize(
    "args,kwargs,expected",
    [
        ((), {}, {"base_path": "./storage", "create_dirs": True}),
        (("/tmp/x",), {}, {"base_path": "/tmp/x", "create_dirs": True}),
        (("/tmp/x", False), {}, {"base_path": "/tmp/x", "create_dirs": False}),
        ((), {"create_dirs": False}, {"base_path": "./storage", "create_dirs": False}),
    ],
)
def test_hook_proxy_store_kwargs_via_dispatch(
    core_stub_hooks: None,
    args: tuple,
    kwargs: dict,
    expected: dict,
) -> None:
    """The runtime proxy forwards positional/keyword args to hook implementations."""
    Jac, _, _ = _runtime()
    result = Jac.store(*args, **kwargs)
    assert result["tier"] == "core"
    assert result["base_path"] == expected["base_path"]
    assert result["create_dirs"] == expected["create_dirs"]


def test_hook_store_dispatch_returns_storage(core_stub_hooks: None) -> None:
    """``Jac.store()`` resolves through the hook proxy to a registered backend."""
    Jac, _, _ = _runtime()
    storage = Jac.store(base_path="./storage", create_dirs=False)
    assert storage is not None
    assert storage["tier"] == "core"


def test_hook_create_j_context_returns_context(core_stub_hooks: None) -> None:
    """``create_j_context`` returns an execution context from the hook layer."""
    Jac, _, _ = _runtime()
    ctx = Jac.create_j_context(
        user_root="user-1", base_path_dir="/proj", full_target_path="/proj/app.jac"
    )
    assert ctx is not None
    assert ctx.tier == "core"
    assert ctx.user_root == "user-1"
    assert ctx.base_path_dir == "/proj"


def test_hook_get_sv_registry_without_scale_deps(declining_scale_stub: None) -> None:
    """When scale declines, ``get_sv_registry`` falls back to the core stub."""
    Jac, _, _ = _runtime()
    reg = Jac.get_sv_registry()
    assert reg == {"core-svc": "http://127.0.0.1:8000"}


def test_hook_get_sv_registry_with_scale_stub(scale_stub_hooks: None) -> None:
    """A later-registered scale stub wins firstresult over the core stub."""
    Jac, _, _ = _runtime()
    reg = Jac.get_sv_registry()
    assert reg == {"scale-svc": "http://scale.local:9000"}


def test_hook_get_api_server_class_scale_override(scale_stub_hooks: None) -> None:
    """``get_api_server_class`` returns the highest-priority non-None hook impl."""
    Jac, _, _ = _runtime()
    cls = Jac.get_api_server_class()
    assert cls.__name__ == "ScaleAPIServer"


def test_hook_get_api_server_class_declines_to_core(declining_scale_stub: None) -> None:
    """Scale returning None lets the core ``get_api_server_class`` hook run."""
    Jac, _, _ = _runtime()
    cls = Jac.get_api_server_class()
    assert cls.__name__ == "CoreAPIServer"


def test_hook_create_server_dispatch(core_stub_hooks: None) -> None:
    """``create_server`` receives host/port through the proxy."""
    Jac, _, _ = _runtime()
    server = Jac.create_server(jac_server=object(), host="127.0.0.1", port=8080)
    assert server.tier == "core"
    assert server.host == "127.0.0.1"
    assert server.port == 8080


def test_hook_sv_service_call_without_scale(declining_scale_stub: None) -> None:
    """``sv_service_call`` falls back to core when scale declines."""
    Jac, _, _ = _runtime()
    out = Jac.sv_service_call("billing", "charge", {"amount": 10})
    assert out["tier"] == "core"
    assert out["module"] == "billing"
    assert out["func"] == "charge"
    assert out["args"] == {"amount": 10}


def test_hook_sv_service_call_with_scale(scale_stub_hooks: None) -> None:
    """``sv_service_call`` uses the scale stub when it is registered last."""
    Jac, _, _ = _runtime()
    out = Jac.sv_service_call("billing", "charge", {})
    assert out["tier"] == "scale"
    assert out["module"] == "billing"


def test_hook_sv_walker_call(core_stub_hooks: None) -> None:
    """``sv_walker_call`` dispatches walker RPC args through the proxy."""
    Jac, _, _ = _runtime()
    out = Jac.sv_walker_call("app", "Ping", {"x": 1}, stub_cls=None)
    assert out["tier"] == "core"
    assert out["walker"] == "Ping"
    assert out["args"] == {"x": 1}


def test_hook_store_scale_override(scale_stub_hooks: None) -> None:
    """Scale ``store`` wins over core when registered after the core stub."""
    Jac, _, _ = _runtime()
    storage = Jac.store(base_path="/data", create_dirs=True)
    assert storage["tier"] == "scale"
    assert storage["base_path"] == "/data"
