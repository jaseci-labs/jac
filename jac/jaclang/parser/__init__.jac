"""Jac Parser Package.

This package provides a hand-written recursive descent parser and lexer for Jac.
The parser is designed to be native-compilation friendly with no runtime reflection.

Grammar specifications are encoded in the AST type structure and can be
automatically extracted at build time using the grammar_gen tool.

Usage:
    import from jaclang.parser { Parser, Lexer }

    source = '''
    obj Hello {
        has name: str;
        def greet() { print(f"Hello, {self.name}!"); }
    }
    ''';

    lexer = Lexer(source, "test.jac");
    parser = Parser(lexer);
    module = parser.parse();

Components:
    - tokens.jac: Token definitions (TokenKind enum, Token class)
    - lexer.jac: Hand-written lexer
    - ast.jac: AST node definitions (grammar encoded in types)
    - parser.jac: Recursive descent parser
"""

# Re-export main API
import from .tokens { Token, TokenKind, SourceLoc }
import from .lexer { Lexer, LexerError }
import from .parser { Parser, ParseError }
