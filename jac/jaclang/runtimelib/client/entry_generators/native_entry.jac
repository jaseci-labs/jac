"""React Native entry-script generator (registry / tests only).

**Production builds do not use this module.** ``jac build`` and ``jac start``
write ``mobile-rn/index.ts`` via ``write_native_entry`` in
``targets/react_native/build.jac``, which calls
``build_native_index_entry_source()`` (Expo ``registerRootComponent`` +
``app/App.tsx`` shell + ``jac-app.js`` bridge).

This module implements the same ``entry_generators`` contract as the web
target (``entry_module`` + ``install_global_handlers``) for registry parity
and unit tests. ``build_registry_native_entry_script`` registers the
compiled module directly via ``AppRegistry`` and is **never** written to
``mobile-rn/index.ts``. Using it expecting production output is a common
mistake — always call ``build_native_index_entry_source`` / ``write_native_entry``
for real builds.

The generator registers under ``react-native`` (and legacy ``native``)
when jac-client bootstraps its client targets.
"""

import from jaclang.runtimelib.entry_generators { register_entry_generator }

# Name passed to AppRegistry / Expo. Must match the Expo project's app name —
# the scaffold writes the same constant into ``app.json``'s ``expo.name``
# field, so changing one without the other breaks the registration lookup.
glob NATIVE_ROOT_COMPONENT_NAME = "main";

"""Build a registry/test-only React Native entry script.

**Not used by ``jac build``.** Production ``index.ts`` content comes from
``build_native_index_entry_source`` in ``targets/react_native/build.jac``.

Args:
    entry_module: Module basename (no extension) whose ``app`` export to
        register. Matches the basename of the compiled JS module in
        ``.jac/client/compiled/``.
    install_global_handlers: Reserved for parity with the web generator.
        On RN, global error handling is set up via ``ErrorUtils`` /
        ``LogBox`` rather than ``window.onerror``; the native runtime
        installs them at module load, so this flag is currently inert and
        kept only so the registry contract is the same shape across
        targets.
"""
def build_registry_native_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    lines: list[str] = [
        'import { AppRegistry } from "react-native";',
        f'import {{ app as JacApp }} from "./{entry_module}.js";',
        '',
        f'AppRegistry.registerComponent({NATIVE_ROOT_COMPONENT_NAME!r}, () => JacApp);',
        ''
    ];
    return "\n".join(lines);
}

"""Register the React Native runtime entry generators."""
def register_native_entry_generators {
    register_entry_generator("react-native", build_registry_native_entry_script);
    register_entry_generator("native", build_registry_native_entry_script);
}
