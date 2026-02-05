"""Jac Parser Package - outputs unitree.py AST nodes.

This package provides a hand-written recursive descent parser and lexer for Jac.
The parser is designed to be native-compilation friendly with no runtime reflection.

The parser outputs unitree.py AST nodes directly, ensuring compatibility with
the existing Jac compiler pipeline.

Usage:
    import from jaclang.compiler.parser { Parser, Lexer, parse }

    source = '''
    obj Hello {
        has name: str;
        def greet() { print(f"Hello, {self.name}!"); }
    }
    ''';

    # Option 1: Use convenience function
    (module, parse_errors, lex_errors) = parse(source, "test.jac");

    # Option 2: Use classes directly
    lexer = Lexer(source=source, file_path="test.jac");
    tokens = lexer.tokenize();
    parser = Parser(tokens=tokens, file_path="test.jac", source_code=source);
    module = parser.parse();

Components:
    - tokens.jac: Token definitions (TokenKind enum, Token class)
    - lexer.jac: Hand-written lexer with f-string and JSX support
    - parser.jac: Recursive descent parser outputting unitree.py nodes
"""

# Re-export main API
import from .tokens { Token, TokenKind, SourceLoc }
import from .lexer { Lexer, LexerError }
import from .parser { Parser, ParseError, parse }

# Re-export unitree types for convenience
import from jaclang.pycore.unitree {
    Module,
    UniNode
}
