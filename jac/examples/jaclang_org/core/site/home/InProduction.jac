glob _AXIS_MAX: int = 640000,
     _TICKS: list[dict[str, any]] = [
         {"v": 0, "label": "0"},
         {"v": 200000, "label": "200K"},
         {"v": 400000, "label": "400K"},
         {"v": 600000, "label": "600K"},

     ],
     _BARS: list[dict[str, any]] = [
         {
             "when": "Before",
             "name": "Next.js + TypeScript, scaled on Supabase",
             "lines": 604840,
             "shown": "604,840",
             "note": "lines removed: the whole Next.js TypeScript codebase",
             "hot": False
         },
         {
             "when": "After",
             "name": "Pure Jac + one jac.toml",
             "lines": 30282,
             "shown": "30,282",
             "note": "lines added: every Jac file and the single jac.toml",
             "hot": True
         },

     ];

def pct(v: int) -> str;

impl pct(v: int) -> str {
    return str(v * 100 / _AXIS_MAX) + "%";
}

def:pub ReductionBars -> JsxElement;

def:pub InProduction -> JsxElement;
