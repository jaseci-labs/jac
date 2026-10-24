import from "motion/react" { motion }

glob ConvPath: any = motion.path,
     _STACKS: list[dict[str, str]] = [
         {
             "name": "Python",
             "eco": "PyPI · servers, data, ML",
             "tools": "pyproject.toml · pip · venv"
         },
         {
             "name": "TypeScript",
             "eco": "npm · browser logic",
             "tools": "package.json · tsc · node"
         },
         {
             "name": "C / C++ / Rust",
             "eco": "C ABI · systems, speed",
             "tools": "CMakeLists.txt · Cargo.toml"
         },
         {"name": "React", "eco": "web UI", "tools": "vite.config.ts · JSX"},
         {
             "name": "React Native",
             "eco": "iOS and Android UI",
             "tools": "metro.config.js · app.json"
         },

     ],
     _PLATFORMS_OUT: list[dict[str, str]] = [
         {"name": "Web", "sub1": "React app", "sub2": "in the browser"},
         {"name": "Mobile", "sub1": "React Native", "sub2": "iOS and Android"},
         {"name": "Desktop", "sub1": "native window", "sub2": "over the OS webview"},
         {"name": "Cloud", "sub1": "API server +", "sub2": "Kubernetes deploy"},
         {"name": "Microservices", "sub1": "each service", "sub2": "its own process"},
         {
             "name": "Databases",
             "sub1": "graph persistence",
             "sub2": "no schema to write"
         },
         {"name": "Native", "sub1": "LLVM binaries", "sub2": "and WebAssembly"},

     ];

def:pub TierLabel(y: int, text: str, hot: bool = False) -> JsxElement;

def:pub ConvergeDiagram -> JsxElement;

glob _LAYERS: list[dict[str, any]] = [
         {"name": "Web", "tools": ["JavaScript", "TypeScript", "React", "CSS", "npm"]},
         {
             "name": "Mobile",
             "tools": [
                 "Swift",
                 "Kotlin",
                 "Xcode",
                 "Android Studio",
                 "App Store",
                 "Google Play"
             ]
         },
         {
             "name": "Backend",
             "tools": ["Python", "FastAPI", "PyPI", "pytest", "Celery"]
         },
         {
             "name": "Database",
             "tools": ["PostgreSQL", "SQLAlchemy", "Alembic", "MongoDB"]
         },
         {"name": "Deployment", "tools": ["Docker", "Kubernetes", "Terraform", "AWS"]},

     ],
     _GLUE_KINDS: list[dict[str, str]] = [
         {"key": "api", "label": "API clients", "color": "#ef4444"},
         {"key": "rest", "label": "REST endpoints", "color": "#a855f7"},
         {"key": "ser", "label": "serializers", "color": "#14b8a6"},
         {"key": "orm", "label": "ORM mapping", "color": "#22c55e"},
         {"key": "schema", "label": "schemas & migrations", "color": "#6366f1"},
         {"key": "deploy", "label": "deployment manifests", "color": "#ec4899"},
         {"key": "config", "label": "config & env variables", "color": "#0ea5e9"},

     ],
     _ROLES: list[dict[str, any]] = [
         {
             "role": "Frontend engineer",
             "lang": "TypeScript · React",
             "kinds": ["ser", "api"],
             "files": [
                 {
                     "name": "App.tsx",
                     "segs": [
                         {"kind": "", "lines": [62, 48]},
                         {"kind": "ser", "lines": [40, 56, 34]},
                         {"kind": "", "lines": [70, 52]},
                         {"kind": "api", "lines": [66, 82, 54, 72, 60, 76, 48]},
                         {"kind": "", "lines": [44, 62, 70, 56, 38, 64]},

                     ]
                 },

             ]
         },
         {
             "role": "Backend engineer",
             "lang": "Python · FastAPI",
             "kinds": ["ser", "rest"],
             "files": [
                 {
                     "name": "main.py",
                     "segs": [
                         {"kind": "", "lines": [72, 58]},
                         {"kind": "ser", "lines": [46, 56, 40, 52, 36]},
                         {
                             "kind": "rest",
                             "lines": [40, 66, 54, 72, 46, 60, 76, 50, 64, 42]
                         },
                         {"kind": "", "lines": [30]},

                     ]
                 },

             ]
         },
         {
             "role": "Data engineer",
             "lang": "Python · SQLAlchemy",
             "kinds": ["schema", "orm"],
             "files": [
                 {
                     "name": "db.py",
                     "segs": [
                         {"kind": "schema", "lines": [56, 70, 46, 62, 50, 66]},
                         {
                             "kind": "orm",
                             "lines": [50, 66, 44, 60, 54, 72, 48, 64, 58, 40, 62]
                         },
                         {"kind": "", "lines": [42, 30]},

                     ]
                 },

             ]
         },
         {
             "role": "DevOps engineer",
             "lang": "Docker · Kubernetes",
             "kinds": ["deploy", "config"],
             "files": [
                 {
                     "name": "Dockerfile",
                     "segs": [{"kind": "deploy", "lines": [50, 40, 62, 46, 70]}]
                 },
                 {
                     "name": "deployment.yaml",
                     "segs": [
                         {"kind": "deploy", "lines": [46, 56, 40, 62, 50, 66, 36]},
                         {"kind": "config", "lines": [52, 66, 42]},

                     ]
                 },

             ]
         },

     ],
     _JAC_FILE: list[dict[str, any]] = [
         {
             "kind": "",
             "lines": [
                 34,
                 52,
                 20,
                 62,
                 48,
                 40,
                 20,
                 58,
                 44,
                 20,
                 60,
                 50,
                 70,
                 40,
                 20,
                 66,
                 30
             ]
         },

     ],
     _IMPORTS: list[dict[str, str]] = [
         {
             "code": "import from sklearn.linear_model { LinearRegression }",
             "eco": "PyPI",
             "out": "Python bytecode, on the server"
         },
         {
             "code": "import from \"date-fns\" { format }",
             "eco": "npm",
             "out": "JavaScript, in the browser"
         },
         {
             "code": "import from \"libm.so\" { def sqrt(x: f64) -> f64; }",
             "eco": "C ABI",
             "out": "native machine code"
         },

     ];

def glue_color(kind: str) -> str;

def glue_label(kind: str) -> str;

def:pub FileGlyph(name: str, segs: list[dict[str, any]]) -> JsxElement;

def:pub GlueChip(kind: str, struck: bool = False) -> JsxElement;

def:pub CompareRow(
    label: str,
    hint: str,
    delta_from: str,
    delta_to: str,
    delta_unit: str,
    left: any = None,
    right: any = None,
    first: bool = False
) -> JsxElement;

def:pub StackCompare -> JsxElement;

def:pub ImportTable -> JsxElement;

def:pub OneLanguage -> JsxElement;

impl glue_color(kind: str) -> str {
    for g in _GLUE_KINDS {
        if g["key"] == kind {
            return g["color"];
        }
    }
    return "";
}

impl glue_label(kind: str) -> str {
    for g in _GLUE_KINDS {
        if g["key"] == kind {
            return g["label"];
        }
    }
    return "";
}
