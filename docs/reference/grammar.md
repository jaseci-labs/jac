---
description: The grammar of Jac, every rule, as jac's parser accepts it.
---
# Grammar

The whole syntax of Jac in EBNF, read out of jac's parser, so it is exactly what the parser accepts. `jac docs <rule>` prints one rule and the pages that explain it: `jac docs archetype`.

- `a b` is a sequence, `a | b` a choice, `a?` optional, `a*` zero or more, `a+` one or more.
- Text in quotes is a keyword or an operator, written as it is.
- An UPPERCASE name is a class of tokens, which the lexical rules at the end define.

This page is written by `jac grammar compiler/parsing/parser.jac --page -o docs/reference/grammar.md`.

```ebnf
# The Jac grammar, read out of jac's parser. Do not edit it by hand:
# `jac grammar compiler/parsing/parser.jac -o compiler/parsing/jac.spec` regenerates it, and
# tests/driver/commands.jac fails while it differs from what the parser accepts.
# Terminals in quotes are keywords and operators; UPPERCASE names are token
# classes, defined by the lexer (the lexical rules close this file).

module ::= STRING? element*

element ::=
    type_alias
    | import_stmt
    | archetype
    | enum_decl
    | test_decl
    | docstring_target
    | ability
    | global_vars
    | comptime_element
    | graph_import
    | graph_spaces
    | graph_layers
    | impl_def
    | sem_def
    | module_code
    | decorated
    | async_element

type_alias ::= "type" access_tag (KEYWORD | NAME) ("[" type_params "]")? (":=" | "=") pipe ";"

import_stmt ::= "comptime"? ("include" | "import" "type"?) ("from" from_path import_items? | (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*) ("as" NAME)? ("," (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*) ("as" NAME)?)* ";")

archetype ::= decorators "async"? ("struct" | "class" | "walker" | "edge" | "obj" | "node") access_tag NAME ("[" type_params "]")? ("(" inherit_list ")")? (":" pipe "-->" pipe)? where_clause? ("{" archetype_member* "}" | ";")

enum_decl ::= decorators "enum" access_tag NAME (":" atomic_chain | "(" atomic_chain ("," atomic_chain)* ")")? ("{" (enum_member "," | module_code)* "}" | ";")

test_decl ::= decorators "test" STRING? block

docstring_target ::= STRING (test_decl | enum_decl | type_alias | global_vars | comptime_element | impl_def | module_code | decorated)

ability ::= decorators "comptime"? "override"? "class"? "static"? "async"? ("def" | "can") access_tag (NAME | "init" | "postinit")? ("[" type_params "]")? (event_sig | func_signature) where_clause? (block | ("by" expression | "abst")? ";")

global_vars ::= "glob" access_tag global_var ("," global_var)* ";"

comptime_element ::= ability | import_stmt | assert_stmt | comptime_global

graph_import ::= "graph" "import" wire_module_path? "{" (STRING import_rule | import_rule | import_wire)* "}"

graph_spaces ::= "graph" "spaces" NAME? "{" (STRING (space_decl | app_decl) | space_decl | app_decl)* "}"

graph_layers ::= "graph" "layers" "{" (STRING layer_decl | layer_decl)* "}"

impl_def ::= decorators "impl" impl_target_name ("." impl_target_name)* ("[" type_params "]")? (func_signature | "(" (atomic_chain ("," atomic_chain)*)? ")" | event_sig)? ("{" ((NAME (":" pipe)? ("=" expression)? ",")* "}" | block_rest) | "by" expression ";")

sem_def ::= "sem" impl_target_name ("." impl_target_name)* "=" STRING+ ";"

module_code ::= "with" ("entry" | "exit")? (":" NAME)? block

decorated ::= test_decl | ability | enum_decl | impl_def | archetype

async_element ::= ability | archetype

access_tag ::= (":" ("protect" | "pub" | "priv"))?

type_params ::= type_param ("," type_param)* ","?

pipe ::= pipe_back ("|>" pipe_back)*

from_path ::= ("." | "...")* (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*)?

import_items ::= "{" (element* | import_item ("," import_item)* ","?) "}"

decorators ::= ("@" atomic_chain)*

inherit_list ::= (call_arg ("," call_arg)* ","?)?

where_clause ::= "where" expression ("," expression)?

archetype_member ::= (STRING? (ability | has_stmt | comptime_global | archetype | enum_decl | impl_def | module_code | stmt))?

atomic_chain ::= atom ("?" (("<." | "." | ".>")? attr_name | index_slice) | ("<." | "." | ".>") attr_name | "(" ("=" (kw_arg ("," kw_arg)* ","?)? | call_args) ")" | "[" filter_body | index_slice)*

enum_member ::= NAME ("=" expression)?

block ::= "{" block_rest

event_sig ::= "with" expression? ("entry" | "exit")

func_signature ::= ("(" func_params ")")? ("->" pipe)?

expression ::= lambda_expr | concurrent ("if" expression "else" expression)?

global_var ::= NAME (":" ownership_prefix pipe)? ("=" expression ("=" expression)*)?

assert_stmt ::= "comptime"? "assert" expression ("," expression)? ";"

comptime_global ::= "comptime" access_tag global_var ("," global_var)* ";"

wire_module_path ::= (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*) ("as" NAME)?

import_rule ::= "edge" NAME ":" module_pattern ("|" module_pattern)* "-->" module_pattern ("|" module_pattern)* (wire_payload | ";")

import_wire ::= "comptime"? ("include" | "type")? wire_module_path ("++>" | "-->") ("[" (wire_target ("," wire_target)* ","?)? "]" | wire_target ";"?)

space_decl ::= "space" NAME ":" (KEYWORD | NAME) "{" (("entry" wire_module_path | module_pattern ("|" module_pattern)*) ";")* "}"

app_decl ::= "app" NAME "{" (NAME "has" NAME ("." NAME)* ("," NAME ("." NAME)*)* ";" | ("run" | "serve") name_list)* "}"

layer_decl ::= "layer" NAME "{" (STRING layer_decl | layer_decl | module_pattern ("|" module_pattern)* ";")* "}"

impl_target_name ::=
    NAME
    | "return"
    | "deleter"
    | "setter"
    | "getter"
    | "default"
    | "exit"
    | "entry"
    | "init"
    | "postinit"

block_rest ::= stmts "}"

type_param ::= "comptime"? NAME (":" pipe)? ("=" pipe)?

pipe_back ::= logical_or ("<|" logical_or)*

import_item ::= ("*" | "default" | any_word | NAME) ("as" NAME)?

call_arg ::= kw_arg | ("**" | "*") expression | expression compr_clauses?

has_stmt ::= "static"? "has" access_tag has_var ("," has_var)* ";"?

stmt ::=
    jsx_element ";"?
    | comptime_stmt
    | import_stmt
    | if_stmt
    | while_stmt
    | open_stmt
    | forever_stmt
    | for_stmt
    | with_stmt
    | try_stmt
    | match_stmt
    | switch_stmt
    | return_stmt
    | yield_expr ";"
    | ctrl_stmt
    | raise_stmt
    | assert_stmt
    | delete_stmt
    | global_vars
    | visit_stmt
    | report_stmt
    | docstring_target
    | ability
    | decorated
    | archetype
    | impl_def
    | has_stmt
    | "->" expression block
    | expression (assignment | ";")

atom ::=
    graph_expr
    | INT
    | FLOAT
    | multistring
    | NAME
    | "None"
    | KEYWORD
    | "..."
    | "*" expression
    | paren_expr
    | bracket_expr
    | brace_expr
    | jsx_element
    | "True"
    | "False"

attr_name ::= NAME | KEYWORD

index_slice ::= "[" ((slice_from | expression slice_from?) ("," (slice_from | expression slice_from?))* ","?)? "]"

kw_arg ::= any_word "=" expression

call_args ::= (call_arg ("," call_arg)* ","?)?

filter_body ::= "?" (":" expression ","?)? (compare ("," compare)*)? "]"

func_params ::= (("*" | "/" | param) ("," ("*" | "/" | param))* ","?)?

lambda_expr ::= "lambda" ("(" func_params ")")? ("->" expression)? ("{" expression "}" | block)

concurrent ::= ("flow" | "wait") walrus | walrus

ownership_prefix ::= ("own" | "lin" | "imm" | "&" "mut"?)?

module_pattern ::= "*" | wire_module_path ("." "*")?

wire_payload ::= "{" (("*" | any_word | NAME) ("as" NAME)? ("," ("*" | any_word | NAME) ("as" NAME)?)* ","?)? "}"

wire_target ::= wire_module_path ("|" wire_module_path)* wire_payload?

name_list ::= NAME ("," NAME)* ";"

stmts ::= stmt*

logical_or ::= logical_and ("or" logical_and)*

any_word ::= NAME | KEYWORD

compr_clauses ::= compr_clause+

has_var ::= NAME ":" pipe ("=" expression | "postinit")? ("{" accessor* "}")?

jsx_element ::=
    "<>" jsx_children "</>"
    | JSX_OPEN ("@" ("{" expression "}" | JSX_NAME ("." JSX_NAME)*) | jsx_tag_name) jsx_attributes ("/>" | JSX_TAG_END jsx_children "</" ("@" ("{" expression "}" | jsx_tag_name) | jsx_tag_name) JSX_TAG_END)

comptime_stmt ::=
    if_stmt
    | for_stmt
    | assert_stmt
    | import_stmt
    | ability
    | "comptime" NAME assignment

if_stmt ::= "comptime"? "if" expression block (elif_stmt | else_stmt)?

while_stmt ::= "while" expression block else_stmt?

open_stmt ::= "in" expression block

forever_stmt ::= "forever" block

for_stmt ::= "comptime"? "async"? "flow"? "for" atomic_chain ("=" expression "while" expression "with" atomic_chain assignment? | "in" expression) block else_stmt?

with_stmt ::= "async"? "with" with_item ("," with_item)* block

try_stmt ::= "try" block ("awaiting" block)? except_clause* else_stmt? ("finally" block)?

match_stmt ::= "match" expression "{" match_case* "}"

switch_stmt ::= "switch" expression "{" switch_case* "}"

return_stmt ::= "return" "tail"? expression? ";"

yield_expr ::= "yield" "from"? expression?

ctrl_stmt ::= ("break" | "continue" | "skip" | "disengage") ";"

raise_stmt ::= "raise" expression? ("from" expression)? ";"

delete_stmt ::= "del" expression ("," expression)* ";"

visit_stmt ::= "visit" (":" expression ":")? expression (else_stmt | ";")

report_stmt ::= "report" expression ";"

assignment ::= (":" ownership_prefix pipe)? ("=" value_or_yield ("=" value_or_yield)* | ("+=" | "-=" | "*=" | "/=" | "//=" | "%=" | "**=" | "@=" | "&=" | "|=" | "^=" | "<<=" | ">>=" | "+%=" | "-%=" | "*%=" | "+|=" | "-|=" | "*|=") value_or_yield)? ";"?

graph_expr ::= "graph" "{" (expression ";")* "}"

multistring ::= string_part+

paren_expr ::= "(" (")" | yield_expr ")" | ability ")" | tuple_item (compr_clauses ")" | ("," tuple_item)* ","? ")" | ")"))

bracket_expr ::= "[" (filter_body | edge_ref_chain | list_or_compr)

brace_expr ::= "{" ("}" | dict_entry ("," dict_entry)* ","? "}" | expression (":" expression (compr_clauses | ("," dict_entry)* ","?) | compr_clauses | ("," expression)* ","?) "}")

slice_from ::= ":" expression? (":" expression?)?

compare ::= cast (("==" | "!=" | "<" | ">" | "<=" | ">=" | "in" | "is" | "not in" | "is not") cast)*

param ::= "comptime"? ("*" | "**")? ("self" | NAME) (":" ownership_prefix pipe)? ("=" expression)?

walrus ::= by_expr (":=" by_expr)?

logical_and ::= logical_not ("and" logical_not)*

compr_clause ::= "async"? "for" atomic_chain "in" pipe ("if" walrus)*

accessor ::= ("deleter" | "getter" | "setter") func_signature? (block | ";")

jsx_children ::= (jsx_child | JSX_TEXT)*

jsx_tag_name ::= JSX_NAME ("." JSX_NAME)*

jsx_attributes ::= (JSX_NAME ("=" ("{" expression "}" | STRING)?)? | "{" ("**" | "...")? expression "}")*

elif_stmt ::= "elif" expression block (elif_stmt | else_stmt)?

else_stmt ::= "else" block

with_item ::= expression ("as" expression)?

except_clause ::= "except" expression ("as" NAME)? block

match_case ::= "case" pattern ("if" expression)? ":" stmt*

switch_case ::= ("case" pattern | "default") ":" stmt*

value_or_yield ::= yield_expr | expression

string_part ::= STRING | fstring

tuple_item ::= "**" expression | expression

edge_ref_chain ::= "async"? ("edge" | "node")? atomic_chain? edge_chain_tail

list_or_compr ::=
    "]"
    | expression (compr_clauses "]" | edge_chain_tail | ("," expression)* ","? "]")

dict_entry ::= ("**" | expression ":") expression

cast ::= bitwise_or ("as" cast_type)*

by_expr ::= pipe ("by" by_expr)?

logical_not ::= "not" logical_not | compare

jsx_child ::=
    JSX_TEXT
    | JSX_COMMENT
    | "{" (stmts "}" | expression (";" stmts "}" | "}"))
    | jsx_element

pattern ::= or_pattern ("as" NAME)?

fstring ::= FSTRING_START (FSTRING_TEXT | formatted_value)* FSTRING_END

edge_chain_tail ::= (edge_op ("[" filter_body | "(" expression ")" | atomic_chain)?)* "]"

bitwise_or ::= bitwise_xor ("|" bitwise_xor)*

cast_type ::= atomic_chain ("|" atomic_chain)*

or_pattern ::= single_pattern ("|" single_pattern)*

formatted_value ::= "{" value_or_yield CONVERSION? (":" (FSTRING_TEXT | formatted_value)*)? "}"

edge_op ::= "->:" edge_filter ":->" | "<-:" edge_filter ":<-" | "<-->" | "-->" | "<--"

bitwise_xor ::= bitwise_and ("^" bitwise_and)*

single_pattern ::=
    list_pattern
    | tuple_pattern
    | mapping_pattern
    | atom
    | literal_pattern
    | name_pattern
    | expression

edge_filter ::= NAME? (":" (compare ("," compare)*)?)?

bitwise_and ::= shift ("&" shift)*

list_pattern ::= "[" (seq_item ("," seq_item)* ","?)? "]"

tuple_pattern ::= "(" seq_item ")"

mapping_pattern ::= "{" (mapping_entry ("," mapping_entry)* ","?)? "}"

literal_pattern ::= signed_number | multistring | expression

name_pattern ::= (NAME ("." any_word)* | KEYWORD) class_pattern?

shift ::= arithmetic (("<<" | ">>") arithmetic)*

seq_item ::= "*" NAME | pattern

mapping_entry ::= "**" NAME | mapping_key ":" pattern

signed_number ::= "-"? (FLOAT | INT)

class_pattern ::= "(" (class_pattern_arg ("," class_pattern_arg)* ","?)? ")"

arithmetic ::= term (("-|" | "+|" | "-%" | "+%" | "+" | "-") term)*

mapping_key ::= signed_number | multistring

class_pattern_arg ::= pattern | (NAME | KEYWORD) "=" pattern

term ::= factor (("*|" | "*%" | "@" | "%" | "//" | "*" | "/") factor)*

factor ::= ("-%" | "+" | "~" | "-") factor | power

power ::= connect ("**" factor)?

connect ::= atomic_pipe (("del" edge_op | "+>:" expression (":" connect_assigns)? ":+>" | "<+:" expression (":" connect_assigns)? (":+>" | ":<+") | "<++>" | "++>" | "<++") atomic_pipe)*

atomic_pipe ::= atomic_pipe_back (":>" atomic_pipe_back)*

connect_assigns ::= (kw_arg ("," kw_arg)* ","?)?

atomic_pipe_back ::= spawn_expr ("<:" spawn_expr)*

spawn_expr ::= "spawn" unpack | unpack ("spawn" unpack)*

unpack ::= "*" ref | ref

ref ::=
    dyn_type
    | ("own" | "imm") await_expr
    | "&" ("mut" await_expr | await_expr)
    | await_expr

dyn_type ::= "dyn" await_expr ("&" await_expr)*

await_expr ::= "await" pipe_call | pipe_call

pipe_call ::= ("|>" | ":>") atomic_chain | atomic_chain

# Lexical rules

KEYWORD ::=
    "str" | "int" | "float" | "list" | "tuple" | "set" | "dict" | "bool" | "bytes"
    | "any" | "type" | "i8" | "u8" | "i16" | "u16" | "i32" | "u32" | "i64" | "u64"
    | "i128" | "u128" | "f16" | "bf16" | "f8e4m3fn" | "f8e5m2" | "f4e2m1fn" | "f32"
    | "f64" | "abst" | "obj" | "class" | "enum" | "node" | "edge" | "walker" | "has"
    | "can" | "def" | "static" | "override" | "comptime" | "impl" | "getter" | "setter"
    | "deleter" | "sem" | "test" | "glob" | "graph" | "import" | "include" | "from"
    | "as" | "if" | "elif" | "else" | "for" | "by" | "while" | "forever" | "match"
    | "switch" | "case" | "default" | "try" | "except" | "finally" | "awaiting" | "with"
    | "return" | "yield" | "break" | "continue" | "raise" | "del" | "assert" | "skip"
    | "report" | "visit" | "spawn" | "entry" | "exit" | "disengage" | "here" | "visitor"
    | "root" | "async" | "await" | "flow" | "wait" | "and" | "or" | "not" | "in" | "is"
    | "lambda" | "own" | "lin" | "mut" | "imm" | "pub" | "priv" | "protect" | "self"
    | "init" | "super" | "postinit" | "True" | "False" | "None"

OPERATOR ::=
    "<-->" | "<++>" | "<--" | "<++" | "<-:" | "<+:" | "<<=" | "</>" | "<=" | "<<" | "<|"
    | "<:" | "<." | "</" | "<>" | "<" | "-->" | "->:" | "-%=" | "-|=" | "->" | "-="
    | "-%" | "-|" | "-" | "++>" | "+>:" | "+%=" | "+|=" | "+=" | "+%" | "+|" | "+"
    | ":->" | ":+>" | ":<-" | ":<+" | ":>" | ":=" | ":" | "..." | ".>" | "." | "**="
    | "*%=" | "*|=" | "**" | "*=" | "*%" | "*|" | "*" | "//=" | "//" | "/=" | "/>" | "/"
    | ">>=" | ">=" | ">>" | ">" | "==" | "=" | "!=" | "|>" | "|=" | "|" | "@=" | "@"
    | "&=" | "&" | "%=" | "%" | "^=" | "^" | "?" | "(" | ")" | "[" | "]" | "{" | "}"
    | "," | ";" | "~"
```
