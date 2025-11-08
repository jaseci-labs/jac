Lexer tokens in Jac define the fundamental building blocks that the lexical analyzer recognizes when parsing source code. These tokens represent the smallest meaningful units of the language.

#### Token Categories

**Built-in type tokens:**
```jac
str int float list tuple set dict bool bytes any type
```

**Declaration keywords:**
```jac
let has can def class obj node edge walker enum impl
```

**Control flow keywords:**
```jac
if elif else for while match case try except finally
```

**Data spatial keywords:**
```jac
visit spawn ignore disengage here visitor entry exit
```

#### Operator Tokens

**Arithmetic operators:**
```jac
+ - * / // % ** @
```

**Comparison operators:**
```jac
== != < <= > >= is in
```

**Assignment operators:**
```jac
= := += -= *= /= //= %= **= @=
```

**Data spatial operators:**
```jac
--> <-- <--> ++> <++ <++>  # Navigation and connection
|> <| :> <: .> <.          # Pipe operators
```

#### Literal Tokens

```jac
42          # Integer
3.14159     # Float
"hello"     # String
True False  # Boolean
None        # Null
```

#### Special Reference Tokens

```jac
init postinit here visitor self super root
```

#### Delimiter Tokens

```jac
( ) [ ] { }     # Grouping
; : , . ... ?   # Punctuation
->              # Return type hint
```

#### Comment Tokens

Single-line comments begin with `#` and extend to the end of the line.  Jac also
supports multiline comments delimited by `#*` and `*#`:

```jac
# This is a line comment
#*
This entire block is ignored by the compiler.
*#
```

#### Identifier Rules

- Case-sensitive token recognition
- Keywords take precedence over identifiers
- Escaped identifiers: `<>reserved_word`

#### Lexical Analysis Process

1. Character stream processing
2. Token recognition using longest match
3. Token classification and value assignment
4. Error reporting with position information
5. Token stream generation for parser

Understanding lexer tokens is fundamental to writing correct Jac code, as these tokens form the basic vocabulary for the language parser.
