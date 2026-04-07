"""AI service for Chat Mode - byllm integration and smart context resolution."""

import os;
import re;
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-5.2");

"""A single file update from the AI."""
obj FileUpdate {
    has path: str;
    has content: str;
}

"""Structured response from the AI code assistant."""
obj CodeUpdateResponse {
    has explanation: str;
    has files: list[FileUpdate];
}

"""You are an expert Jac developer working inside jacBuilder IDE.
Modify Jac code based on the user's request.

CRITICAL RULES:
1. Return ONLY valid, syntactically correct Jac code. Syntax errors will break the live preview.
2. Maintain all existing imports and structure unless the user explicitly asks to change them.
3. Jac syntax: braces {} for blocks, semicolons ; after statements, has for reactive state fields.
4. Client files (.cl.jac) use JSX syntax with Mantine components and Tabler icons.
5. Event handlers: lambda -> None { action(); } or lambda (e: Any) -> None { ... }
6. Conditionals in JSX: (trueVal if condition else falseVal) Python-style, NOT JavaScript ternary.
7. NO JSX comments. Use # comments outside JSX only.
8. Reactive state: has varName: type = default; (equivalent to React useState).
9. NPM imports: cl import from @package { Component }
10. Jac imports: import from .relative.path { symbol }
11. Public functions: def:pub funcName() -> ReturnType { ... }
12. When you modify code, return the COMPLETE file content not just changed parts.
13. If the request is a question not a code change, return an explanation with an empty files list."""
def update_jac_code(
    project_context: str,
    user_request: str
) -> CodeUpdateResponse by llm();


"""Resolve relative Jac imports from a file's content.

Parses `import from .X.Y { ... }` and `cl import from .X.Y { ... }` patterns,
resolves them to file paths, and reads their content.
"""
def resolve_jac_imports(base_dir: str, file_path: str, content: str) -> list[dict] {
    imports: list[dict] = [];
    pattern = r'(?:cl\s+)?import\s+from\s+\.([\w.]+)\s*\{';
    matches = re.findall(pattern, content);

    seen: set = set();
    for match in matches {
        parts = match.split(".");
        candidates = [
            os.path.join(*parts) + ".cl.jac",
            os.path.join(*parts) + ".jac"
        ];
        for candidate in candidates {
            full_path = os.path.join(base_dir, candidate);
            if os.path.isfile(full_path) and candidate not in seen {
                seen.add(candidate);
                try {
                    with open(full_path, "r", encoding="utf-8") as f {
                        imports.append({"path": candidate, "content": f.read()});
                    }
                } except Exception {
                }
                break;
            }
        }
    }
    return imports;
}
