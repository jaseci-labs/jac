"""Exposes BUG: Lexer infinite loop on unterminated JSX.

When JSX content is never closed (missing </div>), the lexer hits EOF
while still in JSX_CONTENT mode. scan_jsx_content returns ERROR without
popping the mode or producing EOF, so tokenize() loops forever.
"""

def app {
    return <div>hello;
}
