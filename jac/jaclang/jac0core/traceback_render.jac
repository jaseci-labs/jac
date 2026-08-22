import from traceback { TracebackException }
import from jaclang.jac0core.helpers {
    pretty_print_source_location,
    read_file_with_encoding
}

def dump_traceback(e: Exception) -> str {
    trace_dump = '';
    def byte_offset_to_char_offset(string: str, offset: int) -> int {
        return len(string.encode('utf-8')[:offset].decode('utf-8', errors='replace'));
    }
    """Return (jac_filename, jac_source) if available, else (None, None).""";
    def get_jac_source_info(py_filename: str) -> tuple[((str | None), (str | None))] {
        return (None, None);
    }
    tb = TracebackException(`type(e), e, e.__traceback__, limit=None, compact=True);
    trace_dump += f"Error: {str(e)}\n";
    tb.stack.pop(0);
    tb.stack.reverse();
    dump_tab_width = 2;
    """Check if a frame is part of the Jac internal runtime.""";
    def is_internal_runtime_frame(filename: str) -> bool {
        normalized: str = filename.replace('\\', '/');
        return (
            ('/jaclang/runtimelib/' in normalized)
            or ('/jaclang/jac0core/' in normalized)
            or ('/jaclang/vendor/' in normalized)
            or ('/jaclang/plugin.py' in normalized)
            or normalized.endswith('/jaclang/meta_importer.py')
        );
    }
    seen_runtime_marker: bool = False;
    collapse_internal: bool = True;
    for (idx, frame) in enumerate(tb.stack) {
        is_internal: bool = is_internal_runtime_frame(frame.filename);
        if (is_internal and collapse_internal) {
            if not seen_runtime_marker {
                trace_dump += f"\n{(' ' * dump_tab_width)}... [internal runtime calls]";
                seen_runtime_marker = True;
            }
            continue;
        }
        seen_runtime_marker = False;
        func_signature: str = frame.name + ('()' if frame.name.isidentifier() else '');
        (jac_filename, jac_source) = get_jac_source_info(frame.filename);
        display_filename: str = jac_filename or frame.filename;
        display_source: (str | None) = jac_source;
        if (
            (idx == 0)
            and (
                (frame.lineno is not None) and frame.line and (frame.line.strip() != '')
            )
        ) {
            line_o = frame.line;
            if frame?._original_line {
                line_o = frame._original_line.rstrip();
            } elif frame?._original_lines {
                line_o = frame._original_lines.split('\n')[0].rstrip();
            }
            if ((frame.colno is not None) and (frame.end_colno is not None)) {
                off_start = byte_offset_to_char_offset(line_o, frame.colno) - 1;
                off_end = byte_offset_to_char_offset(line_o, frame.end_colno) - 1;
                file_source = display_source;
                if (file_source is None) {
                    try {
                        file_source = read_file_with_encoding(frame.filename);
                    } except Exception {
                        file_source = '';
                    }
                }
                if file_source {
                    lines = file_source.split('\n');
                    for i in range((frame.lineno - 1)) {
                        off_start += len(lines[i]) + 1;
                        off_end += len(lines[i]) + 1;
                    }
                    trace_dump += pretty_print_source_location(
                        display_filename, file_source, frame.lineno, off_start, off_end
                    );
                }
            }
        }
        trace_dump += f"\n{(' ' * dump_tab_width)}at {func_signature} {display_filename}:{frame.lineno}";
    }
    return trace_dump;
}
