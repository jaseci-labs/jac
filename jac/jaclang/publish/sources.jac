import from pathlib { Path }
import from jaclang.project.config { JacConfig }

glob DEFAULT_INCLUDE_PATTERNS: list[str] = [
         "**/*.jac",
         "**/*.py",
         "**/*.pyi",
         "**/*.lark",
         "**/py.typed",
         "**/*.jir",

     ],
     EXCLUDED_DIRS: list[str] = [
         ".jac",
         "__pycache__",
         "dist",
         "build",
         "venv",
         ".venv",
         "env",
         ".git",
         ".hg",
         "node_modules",
         "tests",

     ],
     EXCLUDED_SUFFIXES: list[str] = [".pyc"];

glob FLAT_EXCLUDED_DIRS: list[str] = ["docs", "examples", "scripts", ];

obj SourceFile {
    has wheel_path: str = "",
        source_path: Path | None = None,
        content: bytes | None = None;
}

def read_source_file(sf: SourceFile) -> bytes;

def collect_source_files(
    config: JacConfig, project_root: Path | None = None,
) -> list[SourceFile];
