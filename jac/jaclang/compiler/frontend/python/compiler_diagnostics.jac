# Tokenizer warnings reported through the warnings machinery.

def report_token_warnings(scanner: tok_state) {
    if not scanner.warnings {
        return;
    }
    pending = scanner.warnings;
    scanner.warnings = [];
    for warning in pending {
        syntax_warning(
            warning.message,
            warning.filename,
            warning.loc.lineno,
            warning.loc.col_offset
        );
    }
}

def syntax_warning(message: str, filename: str, lineno: int, column: int = 0) {
    warn(message, filename, lineno, column);
}
