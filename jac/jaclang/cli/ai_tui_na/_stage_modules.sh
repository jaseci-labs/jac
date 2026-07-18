# Shared staging for nested tui/ and components/ sources into the flat compile cwd.
# Sourced by build_embed.sh and build_selftest.sh. Sets STAGED_MODULE_FILES for trap cleanup.

STAGED_MODULE_FILES=()

_stage_dir() {
    local src_dir="$1"
    if [ ! -d "$src_dir" ]; then
        return 0
    fi
    local f base dest
    for f in "$src_dir"/*.na.jac; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        dest="$SCRIPT_DIR/$base"
        # Overwrite prior staged copies; refuse only if dest is a tracked real
        # source that is not itself under tui/ or components/.
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            case "$base" in
                screen.na.jac|state.na.jac|runtime.na.jac|host_embed.na.jac|selftest_render.na.jac|input.na.jac|overlay.na.jac|commands.na.jac|theme.na.jac|terminal.na.jac|diff.na.jac|width.na.jac|editor.na.jac|feed.na.jac|keys.na.jac|select_list.na.jac|autocomplete.na.jac|transport.na.jac|ipc.na.jac|ipc_schema.na.jac|util.na.jac|markdown.na.jac|tool_block.na.jac|terminal_image.na.jac|blob_reader.na.jac|tui_loop.na.jac|tui_core.na.jac|reducer.na.jac|interactive_app.na.jac|embed_*.na.jac|bridge_schema.na.jac|session_apply.na.jac)
                    if [ "$(realpath "$f")" != "$(realpath "$dest")" ]; then
                        echo "==> staging conflict: $f -> $base already exists as a real file" >&2
                        exit 1
                    fi
                    ;;
            esac
        fi
        cp "$f" "$dest"
        STAGED_MODULE_FILES+=("$dest")
    done
}

stage_tui_modules() {
    STAGED_MODULE_FILES=()
    _stage_dir "$SCRIPT_DIR/tui"
    _stage_dir "$SCRIPT_DIR/components"
}

cleanup_staged_modules() {
    local f
    for f in "${STAGED_MODULE_FILES[@]:-}"; do
        rm -f "$f"
    done
}
