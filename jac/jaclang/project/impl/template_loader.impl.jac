"""Implementation of template loader functions.

Templates are now defined using a single jac.toml file with an optional [jacpackk]
section. This eliminates the need for a separate manifest file.

The [jacpackk] section contains:
- name: Template name (required)
- description: Template description (required)
- jaclang: Minimum jaclang version (optional)
- plugins: List of required plugins (optional)

The [jacpackk.options] section contains:
- directories: Extra directories to create
- files: Glob patterns for files to include (auto-discovers if not specified)
- root_gitignore_entries: Entries for project root .gitignore
- post_create_hook: Module path to post-create hook function
"""

import from typing { Any, Callable }
import from pathlib { Path }
import from jaclang.project.template_registry { ProjectTemplate }
import json;
import tomllib;
import importlib;
import base64;
import from jaclang.cli.console { console }

# ===============================================================================
# Helper: Read file content (text or binary)
# ===============================================================================
"""Read a file's content, returning text or base64-encoded binary."""
def _read_file_content(file_path: Path) -> str {
    try {
        return file_path.read_text();
    } except UnicodeDecodeError {
        # Binary file - read as bytes and base64 encode
        binary_content = file_path.read_bytes();
        encoded = base64.b64encode(binary_content).decode("ascii");
        return "base64:" + encoded;
    }
}

# ===============================================================================
# Load Template from Directory
# ===============================================================================
"""Load a template from a directory containing jac.toml with [jacpackk] section."""
impl load_template_from_directory(
    template_dir: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate {
    template_dir = Path(template_dir);
    if not template_dir.is_dir() {
        raise ValueError(f"Template directory not found: {template_dir}") ;
    }
    # Load jac.toml
    jac_toml_path = template_dir / "jac.toml";
    if not jac_toml_path.exists() {
        raise ValueError(f"No jac.toml found in {template_dir}") ;
    }
    with open(jac_toml_path, "rb") as f {
        jac_config = tomllib.load(f);
    }
    # Extract template metadata from [jacpack] section
    jacpackk_section = jac_config.get("jacpack", {});
    if not jacpackk_section {
        raise ValueError(f"jac.toml must have [jacpack] section to be packable") ;
    }
    name = jacpackk_section.get("name");
    if not name {
        raise ValueError("jac.toml [jacpack] must have name field") ;
    }
    description = jacpackk_section.get("description", "");
    if not description {
        raise ValueError(
            f"jac.toml [jacpack] for '{name}' must have description field"
        ) ;
    }
    # Build config from jac.toml (everything except [jacpack] section)
    config: dict[str, Any] = {};
    for (key, value) in jac_config.items() {
        if key != "jacpack" {
            config[key] = value;
        }
    }
    # Get options from [template.options]
    options = jacpackk_section.get("options", {});
    directories = options.get("directories", []);
    root_gitignore_entries = options.get("root_gitignore_entries", []);
    gitignore_path = template_dir / ".gitignore";
    if gitignore_path.exists() {
        try {
            gitignore_content = gitignore_path.read_text().strip();
            if gitignore_content {
                for line in gitignore_content.split("\n") {
                    line = line.strip();
                    if line and not line.startswith("#") {
                        if line not in root_gitignore_entries {
                            root_gitignore_entries = root_gitignore_entries + [line];
                        }
                    }
                }
            }
        } except Exception { }
    }
    if ".jac/" not in root_gitignore_entries {
        root_gitignore_entries = root_gitignore_entries + [".jac/"];
    }
    # Resolve post_create hook if specified
    hook = post_create_hook;
    if hook is None and "post_create_hook" in options {
        hook = resolve_post_create_hook(options["post_create_hook"]);
    }
    # Load all template files from the directory
    files: dict[str, str] = {};
    file_patterns = options.get("files", None);
    if file_patterns {
        # Explicit file list provided
        for pattern in file_patterns {
            for file_path in template_dir.glob(pattern) {
                if file_path.is_file() and file_path.name != "jac.toml" {
                    relative_path = str(file_path.relative_to(template_dir));
                    files[relative_path] = _read_file_content(file_path);
                }
            }
        }
    } else {
        # Auto-discover files (excluding jac.toml and hidden files)
        for file_path in template_dir.rglob("*") {
            if file_path.is_file() {
                relative_path = str(file_path.relative_to(template_dir));
                # Skip config and hidden files
                if relative_path != "jac.toml"
                and not relative_path.startswith(".")
                and "/." not in relative_path {
                    files[relative_path] = _read_file_content(file_path);
                }
            }
        }
    }
    return ProjectTemplate(
        name=name,
        description=description,
        config=config,
        files=files,
        directories=directories,
        root_gitignore_entries=root_gitignore_entries,
        post_create=hook
    );
}

# ===============================================================================
# Bundle Template to JSON
# ===============================================================================
"""Bundle a template directory into a single JSON file."""
impl bundle_template(template_dir: Path, output_path: Path) -> None {
    template_dir = Path(template_dir);
    output_path = Path(output_path);
    if not template_dir.is_dir() {
        raise ValueError(f"Template directory not found: {template_dir}") ;
    }
    # Load jac.toml to get template metadata
    jac_toml_path = template_dir / "jac.toml";
    if not jac_toml_path.exists() {
        raise ValueError(f"No jac.toml found in {template_dir}") ;
    }
    with open(jac_toml_path, "rb") as f {
        jac_config = tomllib.load(f);
    }
    jacpackk_section = jac_config.get("jacpack", {});
    if not jacpackk_section {
        raise ValueError(f"jac.toml must have [jacpack] section to be packable") ;
    }
    # Load template (without resolving hook - we'll store it as string)
    template = load_template_from_directory(template_dir, post_create_hook=None);
    # Convert to dict for JSON serialization
    template_data = template.to_dict();
    # Add version metadata from [jacpack] section
    if "jaclang" in jacpackk_section {
        template_data["jaclang"] = jacpackk_section["jaclang"];
    }
    if "plugins" in jacpackk_section {
        template_data["plugins"] = jacpackk_section["plugins"];
    }
    # Store hook path as string instead of callable
    options = jacpackk_section.get("options", {});
    if "post_create_hook" in options {
        template_data["post_create_hook"] = options["post_create_hook"];
    }
    # Write bundled JSON
    with open(output_path, "w") as f {
        json.dump(template_data, f, indent=2);
    }
    console.print(f"Bundled template '{template.name}' to {output_path}");
}

# ===============================================================================
# Load Template from JSON
# ===============================================================================
"""Load a template from a bundled JSON file."""
impl load_template_from_json(
    json_path: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate {
    json_path = Path(json_path);
    if not json_path.exists() {
        raise ValueError(f"Template JSON not found: {json_path}") ;
    }
    with open(json_path, "r") as f {
        data = json.load(f);
    }
    # Resolve hook if specified
    hook = post_create_hook;
    if hook is None and "post_create_hook" in data {
        hook = resolve_post_create_hook(data["post_create_hook"]);
    }
    return ProjectTemplate(
        name=data["name"],
        description=data["description"],
        config=data.get("config", {}),
        files=data.get("files", {}),
        directories=data.get("directories", []),
        root_gitignore_entries=data.get("root_gitignore_entries", []),
        post_create=hook
    );
}

# ===============================================================================
# Hook Resolution
# ===============================================================================
"""Resolve a post_create hook from a string path."""
impl resolve_post_create_hook(hook_path: str) -> Callable | None {
    if not hook_path {
        return None;
    }
    try {
        # Parse "module.path:function_name" format
        if ":" in hook_path {
            parts = hook_path.split(":");
            module_path = parts[0];
            func_name = parts[1];
        } else {
            # Assume last component is function name
            parts = hook_path.rsplit(".", 1);
            if len(parts) != 2 {
                raise ValueError(f"Invalid hook path format: {hook_path}") ;
            }
            module_path = parts[0];
            func_name = parts[1];
        }

        module = importlib.import_module(module_path);
        hook = getattr(module, func_name);

        if not callable(hook) {
            raise ValueError(f"Hook '{hook_path}' is not callable") ;
        }

        return hook;
    } except ImportError as e {
        console.print(f"Warning: Could not import hook module '{hook_path}': {e}");
        return None;
    } except AttributeError as e {
        console.print(f"Warning: Hook function not found '{hook_path}': {e}");
        return None;
    }
}
