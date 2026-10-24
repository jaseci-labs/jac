import from "@jac/runtime" { Link }

glob _FPS_MAX: int = 3500,
     _FPS_TICKS: list[dict[str, any]] = [
         {"v": 0, "label": "0"},
         {"v": 1000, "label": "1K"},
         {"v": 2000, "label": "2K"},
         {"v": 3000, "label": "3K"},

     ],
     _RUNS: list[dict[str, any]] = [
         {
             "lang": "Jac",
             "build": "jac build --native",
             "fps": 3225.9,
             "shown": "3,225.9",
             "frames": "25,808",
             "hot": True
         },
         {
             "lang": "Zig",
             "build": "zig build-exe",
             "fps": 3235.7,
             "shown": "3,235.7",
             "frames": "25,886",
             "hot": False
         },
         {
             "lang": "Rust",
             "build": "rustc -C opt-level=3",
             "fps": 3223.1,
             "shown": "3,223.1",
             "frames": "25,785",
             "hot": False
         },
         {
             "lang": "Python",
             "build": "CPython 3.14.6 · ctypes",
             "fps": 1588.4,
             "shown": "1,588.4",
             "frames": "12,708",
             "hot": False
         },

     ];

def fps_pct(v: float) -> str;

impl fps_pct(v: float) -> str {
    return str(v * 100 / _FPS_MAX) + "%";
}

def:pub FpsBars -> JsxElement;

def:pub NativeBench -> JsxElement;
