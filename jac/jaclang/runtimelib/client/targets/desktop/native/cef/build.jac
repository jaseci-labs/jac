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
