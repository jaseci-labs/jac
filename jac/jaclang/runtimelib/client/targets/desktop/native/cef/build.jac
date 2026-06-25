"""Build the CEF native pieces (libcef_dispatch.so + cef-subprocess) in place.

Standalone entry for CI and manual rebuilds; the CefDesktopTarget build pipeline
calls the same desktop_build functions directly. Run it from anywhere:

    jac run jaclang/runtimelib/client/targets/desktop/native/cef/build.jac

Compiles with `jac nacompile` only -- no gcc, no CEF runtime, no display. The
shared cef_platform.na.jac fragment is spliced in by desktop_build._splice_platform
(the in-Jac replacement for the old awk pass in build_cef_*.sh).
"""
import os;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client.targets.desktop.desktop_build {
    build_cef_dispatch,
    build_cef_subprocess,
}

glob cef_dir = Path(os.path.abspath(__file__)).parent;

with entry {
    console.print(f">> building libcef_dispatch.so in {cef_dir}");
}

glob dispatch = build_cef_dispatch(cef_dir);

with entry {
    console.print(f">> built {dispatch}");
    console.print(">> building cef-subprocess");
}

glob helper = build_cef_subprocess(cef_dir);

with entry {
    console.print(f">> built {helper}");
    console.print("OK.");
}
