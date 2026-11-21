import os;
import from pathlib { Path }

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
