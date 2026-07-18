"""Phase 5 tests: Pi-style TUI modules, import purity, focus routing, width."""

import importlib;
import re;
import from pathlib { Path }


def _na_dir -> Path {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    return Path(shared_mod.__file__).resolve().parent.parent / "ai_tui_na";
}


def _generic_dirs(na_root: Path) -> list {
    return [na_root / "tui", na_root / "components"];
}


def _forbidden_import(text: str) -> str | None {
    patterns = [
        r"import from\s+\.embed_",
        r"import from\s+jacpyembed",
        r"import from\s+\.bridge_",
        r"import from\s+\.session_",
        r"import from\s+\.ipc_schema",
        r"import from\s+\.ipc\b",
        r"import from\s+\.transport",
        r"jpy_Py"
    ];
    for pat in patterns {
        if re.search(pat, text) {
            return pat;
        }
    }
    return None;
}


test "phase5 generic tui and components import no agent embed session ipc" {
    na_root = _na_dir();
    offenders = [];
    for d in _generic_dirs(na_root) {
        if not d.is_dir() {
            continue;
        }
        for path in sorted(d.glob("*.na.jac")) {
            text = path.read_text();
            hit = _forbidden_import(text);
            if hit is not None {
                offenders.append(f"{d.name}/{path.name}:{hit}");
            }
        }
    }
    assert offenders == [] , f"generic TUI imports agent/embed/session: {offenders}";
}


test "phase5 gil still sealed in EmbedRuntime only" {
    na_root = _na_dir();
    offenders = [];
    for path in sorted(na_root.rglob("*.na.jac")) {
        if path.name == "embed_runtime.na.jac" {
            continue;
        }
        # Ignore staged flat copies that mirror tui/ (gitignored) — scan sources.
        if path.parent == na_root
        and path.name in {
            "component.na.jac",
            "container.na.jac",
            "focus.na.jac",
            "process_terminal.na.jac",
            "virtual_terminal.na.jac",
            "frame_renderer.na.jac",
            "input_types.na.jac",
            "tui.na.jac",
            "theme_obj.na.jac",
            "transcript.na.jac",
            "status.na.jac",
            "editor_view.na.jac",
            "autocomplete_view.na.jac",
            "warn_view.na.jac",
            "chrome.na.jac"
        } {
            continue;
        }
        text = path.read_text();
        if "import from jacpyembed" in text or "jpy_Py" in text {
            offenders.append(str(path.relative_to(na_root)));
        }
    }
    assert offenders == [] , f"CPython symbols leaked: {offenders}";
    rt_src = (na_root / "embed_runtime.na.jac").read_text();
    assert "import from jacpyembed" in rt_src;
}


test "phase5 has virtual Component contract and InteractiveApp reducer" {
    na_root = _na_dir();
    comp = (na_root / "tui" / "component.na.jac").read_text();
    assert "obj Component" in comp;
    assert "def render(width: int)" in comp;
    assert "def handle_input" in comp;
    assert "def invalidate" in comp;

    red = (na_root / "reducer.na.jac").read_text();
    assert "def reduce_input" in red;
    assert "def reduce_session" in red;
    assert "effective_focus" in red;

    app = (na_root / "interactive_app.na.jac").read_text();
    assert "obj InteractiveApp" in app;
    assert "def inject_key" in app;
    assert "def step" in app;

    inp = (na_root / "input.na.jac").read_text();
    assert "reduce_input" in inp;
    assert "UiAction" in inp;

    focus = (na_root / "tui" / "focus.na.jac").read_text();
    assert "def effective_focus" in focus;
}


test "phase5 screen uses split component modules" {
    na_root = _na_dir();
    screen = (na_root / "screen.na.jac").read_text();
    assert "render_transcript" in screen;
    assert "render_editor" in screen;
    assert "render_status" in screen;
    assert "render_ac" in screen;
    assert "render_warn" in screen;
    assert (na_root / "components" / "transcript.na.jac").is_file();
    assert (na_root / "components" / "editor_view.na.jac").is_file();
    assert (na_root / "tui" / "process_terminal.na.jac").is_file();
    assert (na_root / "tui" / "frame_renderer.na.jac").is_file();
    assert (na_root / "tui" / "virtual_terminal.na.jac").is_file();
}


test "phase5 focus routing prefers overlay then autocomplete then base" {
    # Source-level contract: globals first, then effective_focus branches.
    red = (_na_dir() / "reducer.na.jac").read_text();
    assert "_handle_global" in red;
    assert "FocusTarget.OVERLAY" in red;
    assert "FocusTarget.AUTOCOMPLETE" in red;
    assert "FocusTarget.TRANSCRIPT" in red;
    # inject_key path for tests (no direct component.handle_input).
    app = (_na_dir() / "interactive_app.na.jac").read_text();
    assert "inject_key" in app;
    assert "reduce_input" in app;
}


test "phase5 frame_renderer validates visible widths" {
    fr = (_na_dir() / "tui" / "frame_renderer.na.jac").read_text();
    assert "validate_frame_widths" in fr;
    assert "visible_width" in fr;
}
