import re;
import json as json_mod;
import from pathlib { Path }

glob _SHADCN_TAILWIND_CSS: str = """/* Vendored from shadcn v3.8.5 dist/tailwind.css (no npm dep needed) */
@theme inline {
  @keyframes accordion-down {
    from {
      height: 0;
    }
    to {
      height: var(
        --radix-accordion-content-height,
        var(--accordion-panel-height, auto)
      );
    }
  }

  @keyframes accordion-up {
    from {
      height: var(
        --radix-accordion-content-height,
        var(--accordion-panel-height, auto)
      );
    }
    to {
      height: 0;
    }
  }
}

/* Custom variants */
@custom-variant data-open {
  &:where([data-state="open"]),
  &:where([data-open]:not([data-open="false"])) {
    @slot;
  }
}

@custom-variant data-closed {
  &:where([data-state="closed"]),
  &:where([data-closed]:not([data-closed="false"])) {
    @slot;
  }
}

@custom-variant data-checked {
  &:where([data-state="checked"]),
  &:where([data-checked]:not([data-checked="false"])) {
    @slot;
  }
}

@custom-variant data-unchecked {
  &:where([data-state="unchecked"]),
  &:where([data-unchecked]:not([data-unchecked="false"])) {
    @slot;
  }
}

@custom-variant data-selected {
  &:where([data-selected="true"]) {
    @slot;
  }
}

@custom-variant data-disabled {
  &:where([data-disabled="true"]),
  &:where([data-disabled]:not([data-disabled="false"])) {
    @slot;
  }
}

@custom-variant data-active {
  &:where([data-state="active"]),
  &:where([data-active]:not([data-active="false"])) {
    @slot;
  }
}

@custom-variant data-horizontal {
  &:where([data-orientation="horizontal"]) {
    @slot;
  }
}

@custom-variant data-vertical {
  &:where([data-orientation="vertical"]) {
    @slot;
  }
}

@utility no-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;

  &::-webkit-scrollbar {
    display: none;
  }
}""";

glob _DEFAULTS: dict[str, str] = {
         "style": "nova",
         "baseColor": "neutral",
         "theme": "neutral",
         "font": "figtree",
         "radius": "default",
         "menuAccent": "subtle",
         "menuColor": "default"
     },
     _SHADCN_KEYS: list[str] = [
         "style",
         "baseColor",
         "theme",
         "font",
         "radius",
         "menuAccent",
         "menuColor"
     ],
     RADII_MAP: dict[str, str] = {
         "none": "0",
         "small": "0.45rem",
         "medium": "0.625rem",
         "large": "0.875rem"
     },
     FONT_DATA: dict[str, dict[str, str]] = {
         "geist": {
             "family": "'Geist Variable', sans-serif",
             "npm": "@fontsource-variable/geist"
         },
         "inter": {
             "family": "'Inter Variable', sans-serif",
             "npm": "@fontsource-variable/inter"
         },
         "noto-sans": {
             "family": "'Noto Sans Variable', sans-serif",
             "npm": "@fontsource-variable/noto-sans"
         },
         "nunito-sans": {
             "family": "'Nunito Sans Variable', sans-serif",
             "npm": "@fontsource-variable/nunito-sans"
         },
         "figtree": {
             "family": "'Figtree Variable', sans-serif",
             "npm": "@fontsource-variable/figtree"
         },
         "roboto": {
             "family": "'Roboto Variable', sans-serif",
             "npm": "@fontsource-variable/roboto"
         },
         "raleway": {
             "family": "'Raleway Variable', sans-serif",
             "npm": "@fontsource-variable/raleway"
         },
         "dm-sans": {
             "family": "'DM Sans Variable', sans-serif",
             "npm": "@fontsource-variable/dm-sans"
         },
         "public-sans": {
             "family": "'Public Sans Variable', sans-serif",
             "npm": "@fontsource-variable/public-sans"
         },
         "outfit": {
             "family": "'Outfit Variable', sans-serif",
             "npm": "@fontsource-variable/outfit"
         },
         "jetbrains-mono": {
             "family": "'JetBrains Mono Variable', monospace",
             "npm": "@fontsource-variable/jetbrains-mono"
         },
         "geist-mono": {
             "family": "'Geist Mono Variable', monospace",
             "npm": "@fontsource-variable/geist-mono"
         }
     },
     THEME_INLINE_COLORS: list[str] = [
         "sidebar-ring",
         "sidebar-border",
         "sidebar-accent-foreground",
         "sidebar-accent",
         "sidebar-primary-foreground",
         "sidebar-primary",
         "sidebar-foreground",
         "sidebar",
         "chart-5",
         "chart-4",
         "chart-3",
         "chart-2",
         "chart-1",
         "ring",
         "input",
         "border",
         "destructive",
         "accent-foreground",
         "accent",
         "muted-foreground",
         "muted",
         "secondary-foreground",
         "secondary",
         "primary-foreground",
         "primary",
         "popover-foreground",
         "popover",
         "card-foreground",
         "card",
         "foreground",
         "background"
     ],
     _UTILS_CONTENT: str = 'import from "clsx" { clsx }\nimport from "tailwind-merge" { twMerge }\n\ndef:pub cn(*inputs: any) -> str {\n    return twMerge(clsx(inputs));\n}\n';

def _utils_source -> str;

def normalize_shadcn_config(raw: (dict[str, any] | None)) -> dict[str, str];

def load_themes -> list[dict[str, any]];

def find_theme(name: str) -> any;

def resolve_css_vars(shadcn_config: dict[str, str]) -> dict[str, dict[str, str]];

def generate_global_css(font_value: str, css_vars: dict[str, dict[str, str]]) -> str;

def generate_starter_main_jac -> str;

def _render_shadcn_block(shadcn_config: dict[str, str]) -> str;

def set_shadcn_section(toml_path: any, shadcn_config: dict[str, str]);

def _toml_key(key: str) -> str;

def _patch_npm_deps(toml_path: any, npm_deps: dict[str, str]) -> None;

def _ensure_vite_tailwind(toml_path: any) -> None;

def _install_component(ui_dir: any, name: str, style: str) -> list[str];

def materialize_themed_starter(
    project_root: any, project_name: str, shadcn_config: dict[str, str]
) -> bool;

def _theme_app_root(config: any, project_root: Path) -> Path;

def retheme_project(config: any, overrides: dict[str, str | None]) -> bool;
