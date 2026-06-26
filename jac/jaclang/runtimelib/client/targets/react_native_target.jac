"""React Native build target.

Implements the Expo + Metro + native-runtime path for
``--client react-native``. Unlike ``MobileTarget``, this target does **not**
extend ``WebTarget`` (D3): Metro replaces Vite end-to-end, so inheriting the
web bundle pipeline would couple us to internals we explicitly need to
diverge from.
"""
import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.watcher { FileChangeEvent }
import from jaclang.runtimelib.client.targets.registry { ClientTarget }
import from jaclang.runtimelib.client.targets.client_dev_common { _ClientHmrHandler }

"""Binds JacClientCompiler state for JacFileWatcher (decl only; see impl).

Extends ``_ClientHmrHandler`` for the shared compiler/entry/project state
and adds the two RN-specific pieces (``rn_dir`` + ``entry_module``) that
the Metro re-stage path needs. ``on_event`` is implemented in
``react_native_target.impl.jac`` to call the RN recompile + re-stage
pipeline. ``ReactNativeTarget.dev`` instantiates this from its watcher
callback and hands the bound ``on_event`` to ``JacFileWatcher.add_callback``.
"""
obj _RNHmrHandler(_ClientHmrHandler) {
    has rn_dir: Path,
        entry_module: str;

    def on_event(evt: FileChangeEvent) -> None;
}

"""React Native build target (Expo + Metro + Hermes + New Architecture).

The defaults mirror the documented Expo / Hermes / project-dir choices:
  * Expo (not bare RN) — `requires_setup = True`, scaffold lives in
    ``mobile-rn/`` so it doesn't collide with the Capacitor ``android/`` and
    ``ios/`` directories (D11).
  * Production stack from day one: Hermes, New Architecture, secure-store.
  * Output directory points at ``mobile-rn/dist`` to keep native artifacts
    isolated from the scaffold.
"""
obj ReactNativeTarget(ClientTarget) {
    has name: str = "react-native",
        default: bool = False,
        requires_setup: bool = True,
        config_section: str = "react_native",
        output_dir: Path = Path("mobile-rn/dist");

    """Setup the Expo project scaffold under ``mobile-rn/``."""
    override def setup(project_dir: Path) -> None;

    """Build a debug APK/IPA or release artifact."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Start the Metro dev loop with Fast Refresh."""
    override def dev(
        entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
    ) -> None;

    """Build then launch on a connected device or emulator."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Compile the Jac entry module + native runtime into ``compiled_dir``.

    Shared by ``build`` and ``dev`` — reaches through ``ViteCompiler`` to
    the inner ``JacClientCompiler`` (bypassing ViteCompiler's web-only
    ``create_entry_file``) and emits ``client_runtime_native.cl.jac``.
    Returns the ``JacClientCompiler`` instance and ``compiled_dir`` so
    callers can stage entries / bind HMR handlers against them.
    """
    def:priv _compile_native_jac_modules(entry_file: Path) -> tuple[(any, Path)];
}
