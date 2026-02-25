access_tag ::= (":" ("pub" | "priv" | "protect")?)?

module ::= STRING? element_stmt*

expression ::= lambda_expr | concurrent_expr ("if" expression "else" expression)?

concurrent_expr ::= ("flow" | "wait") walrus_assign | walrus_assign

walrus_assign ::= by_expr (":=" by_expr)?

by_expr ::= pipe ("by" by_expr)?

pipe ::= pipe_back ("|>" pipe_back)*

pipe_back ::= logical_or ("<|" logical_or)*

bitwise_or ::= bitwise_xor ("|" bitwise_xor)*

bitwise_xor ::= bitwise_and ("^" bitwise_and)*

bitwise_and ::= shift ("&" shift)*

shift ::= arithmetic (("<<" | ">>") arithmetic)*

logical_or ::= logical_and ("or" logical_and)*

logical_and ::= logical_not ("and" logical_not)*

logical_not ::= "not" logical_not | compare

compare ::=
    bitwise_or (
        ("==" | "!=" | "<" | ">" | "<=" | ">=" | "in" | "is" | "not in" | "is not")
        bitwise_or
    )*

arithmetic ::= term (("+" | "-") term)*

term ::= power (("*" | "/" | "//" | "%" | "@") power)*

power ::= factor ("**" power)?

factor ::= ("~" | "-" | "+") factor | connect

connect ::= atomic_pipe (connect_op atomic_pipe)*

edge_op_ref_inline ::=
    "-->"
    | "<--"
    | "<-->"
    | "->:" ((NAME | KWESC_NAME) atom)? ":->"?
    | "<-:" ((NAME | KWESC_NAME) atom)? ":<-"?

connect_op ::=
    "del" edge_op_ref_inline
    | "++>"
    | "+>:" expression (":" (expression ("=" expression)?)*)? ":+>"
    | "<++"
    | "<+:" expression (":" (expression ("=" expression)?)*)? (":<+" | ":+>")?
    | "<++>"

atomic_pipe ::= atomic_pipe_back (":>" atomic_pipe_back)*

atomic_pipe_back ::= spawn ("<:" spawn)*

spawn ::= "spawn" unpack | unpack ("spawn" unpack)*

unpack ::= "*" ref | ref

ref ::= "&" await_expr | await_expr

await_expr ::= "await" pipe_call | pipe_call

pipe_call ::= ("|>" | ":>") atomic_chain | atomic_chain

atomic_chain ::=
    atom (
        "." ("." | ".>" | "<.")? (
            NAME
            | KWESC_NAME
            | "init"
            | "postinit"
            | "self"
            | "props"
            | "super"
            | "root"
            | "here"
            | "visitor"
        )?
        | "(" (filter_compr_inner | assign_compr_inner | call_args ")")
        | "?"? "[" expression? (
              ":" expression? (":" expression?)?
              ("," expression? ":" expression? (":" expression?)?)* "]"
              | ("," expression)* "]"
          )
    )*

call_args ::= call_arg ("," call_arg)*

call_arg ::=
    (NAME | KWESC_NAME) "=" expression
    | "**" expression
    | "*" expression
    | expression comprehension_clauses?

filter_compr_inner ::= "?" (":" expression)? ","? (compare ("," compare)*)? ")"

assign_compr_inner ::= "=" (NAME "=" expression ("," NAME "=" expression)*)? ")"

atom_literal ::= INT | HEX | BIN | OCT | FLOAT | BOOL | NULL | ELLIPSIS

multistring ::= (NAME | STRING | fstring) (NAME | STRING | fstring)*

builtin_type ::=
    "str"
    | "int"
    | "float"
    | "list"
    | "tuple"
    | "set"
    | "dict"
    | "bool"
    | "bytes"
    | "any"
    | "type"

special_ref ::=
    "self"
    | "super"
    | "here"
    | "root"
    | "visitor"
    | "props"
    | "init"
    | "postinit"
    | "node"
    | "edge"
    | "walker"
    | "obj"
    | "class"
    | "enum"

atom ::=
    atom_literal
    | multistring
    | builtin_type
    | special_ref
    | (NAME | KWESC_NAME) NAME?
    | NAME
    | "*" expression
    | "**" expression
    | "(" (
          ")"
          | yield_stmt ")"
          | ("def" | "can" | "async") ability ")"
          | expression (comprehension_clauses ")" | "," (expression ","?)* ")" | ")")
      )
    | "[" (
          "-->"
          | "<--"
          | "<-->"
          | "->:"
          | "<-:"
          | "->"
          | "async"
          | ("node" | "edge") (
                "-->"
                | "<--"
                | "<-->"
                | "->:"
                | "<-:"
                | "->"
                | NAME
                | "root"
                | "self"
                | "here"
                | "super"
                | "visitor"
            )?
          | (NAME | "root" | "self" | "here" | "super" | "visitor")
            ("-->" | "<--" | "<-->" | "->:" | "<-:" | "->" | ("[" | "]")?)?
      )? (edge_ref_chain | list_or_compr)
    | "{" dict_or_set
    | jsx_element

fstring ::= ("{{" | "}}" | "{" expression CONV? (":" ("{" expression CONV? "}")*)? "}")*

list_or_compr ::= "]" | expression (comprehension_clauses "]" | ("," expression)* "]")

edge_ref_chain ::=
    "async"? ("edge" | "node")? (
        (NAME | KWESC_NAME | "root" | "self" | "here" | "super" | "visitor" | "[")
        atomic_chain
    )? (
        (
            "-->"
            | "<--"
            | "<-->"
            | "->" atom? (":" (compare ("," compare)*)?)? ":->"
            | "<-:" ((NAME | KWESC_NAME) atom)? (":" (compare ("," compare)*)?)? ":<-"
            | "->:" ((NAME | KWESC_NAME) atom)? ":->"
        ) (
            "(" (filter_compr_inner | expression ")")
            | (NAME | KWESC_NAME | "self" | "root" | "here" | "super") atomic_chain
        )?
    )* "]"

dict_or_set ::=
    "}"
    | dict_with_spread
    | expression (
          ":" expression (
              comprehension_clauses "}"
              | ("," ("**" expression | expression ":" expression))* "}"
          )
          | comprehension_clauses "}"
          | ("," expression)* "}"
      )

dict_with_spread ::= ("**" expression | expression ":" expression)* "}"

comprehension_clauses ::=
    ("async"? "for" atomic_chain "in" pipe_call ("if" walrus_assign)*)*

lambda_expr ::=
    "lambda" ("(" func_params ")" | lambda_params) ("->" expression)?
    (":" expression | "{" code_block_stmts "}" | expression)

lambda_params ::= ("*"? "/"? ("*" | "**")? (":" pipe)? ("=" expression)?)*

jsx_element ::=
    "<>" jsx_children "</>"
    | JSX_OPEN_START JSX_NAME ("." JSX_NAME)* jsx_attributes
      ("/>" | JSX_TAG_END jsx_children "</" JSX_NAME ("." JSX_NAME)* JSX_TAG_END)

jsx_attributes ::=
    (JSX_NAME ("=" (STRING | "{" expression "}")?)? | "{" ELLIPSIS? expression "}")*

jsx_children ::= jsx_child*

jsx_child ::= JSX_TEXT jsx_child? | "{" expression "}" | jsx_element

element_stmt ::=
    ";"
    | "cl" (client_block | element_stmt)?
    | "sv" (server_block | element_stmt)?
    | "na" (native_block | element_stmt)?
    | type_alias
    | import_stmt
    | archetype
    | enum
    | STRING test
    | test
    | STRING ("@" atomic_chain)* "async"* (archetype | enum | impl_def | ability)
    | STRING enum
    | ability
    | STRING type_alias
    | STRING global_var
    | global_var
    | STRING impl_def
    | impl_def
    | sem_def
    | PYNLINE
    | STRING module_code
    | module_code
    | "@" ability
    | "async" ability

client_block ::= "cl" ("{" element_stmt* "}" | element_stmt)

server_block ::= "sv" ("{" element_stmt* "}" | element_stmt)

native_block ::= "na" ("{" element_stmt* "}" | element_stmt)

module_code ::= "with" ("exit" | "entry")? (":" NAME)? "{" code_block_stmts "}"

code_block_stmts ::= (statement ";"?)*

ctrl_stmt ::= ("break" | "continue" | "skip") ";" | "disengage" ";"

statement ::=
    ";"
    | import_stmt
    | if_stmt
    | while_stmt
    | for_stmt
    | with_stmt
    | try_stmt
    | match_stmt
    | switch_stmt
    | return_stmt
    | yield_stmt ";"
    | ctrl_stmt
    | raise_stmt
    | assert_stmt
    | delete_stmt
    | global_stmt
    | nonlocal_stmt
    | visit_stmt
    | report_stmt
    | ability
    | archetype
    | enum
    | impl_def
    | has_stmt
    | PYNLINE
    | "->" expression "{" code_block_stmts "}"
    | expression (assignment_with_target | ";"?)

if_stmt ::= "if" expression "{" code_block_stmts "}" (elif_stmt | else_stmt)?

elif_stmt ::= "elif" expression "{" code_block_stmts "}" (elif_stmt | else_stmt)?

else_stmt ::= "else" "{" code_block_stmts "}"

while_stmt ::= "while" expression "{" code_block_stmts "}" else_stmt?

for_stmt ::=
    "async"? "for" atomic_chain (
        "=" expression "to" pipe "by" atomic_chain assignment_with_target? "{"
        code_block_stmts "}" else_stmt?
        | "in" expression "{" code_block_stmts "}" else_stmt?
    )

try_stmt ::=
    "try" "{" code_block_stmts "}" except_handler* else_stmt?
    ("finally" "{" code_block_stmts "}")?

except_handler ::= "except" expression ("as" NAME)? "{" code_block_stmts "}"

with_stmt ::=
    "async"? "with" expression ("as" expression)? ("," expression ("as" expression)?)*
    "{" code_block_stmts "}"

match_stmt ::= "match" expression "{" match_case* "}"

match_case ::= "case" pattern ("if" expression)? ":" statement*

pattern ::= or_pattern ("as" NAME)?

or_pattern ::= single_pattern ("|" single_pattern)*

single_pattern ::=
    sequence_pattern
    | tuple_sequence_pattern
    | mapping_pattern
    | BOOL
    | NULL
    | INT
    | FLOAT
    | multistring (
          "-" (INT | FLOAT)?
          | (NAME | KWESC_NAME) (("." NAME)* class_pattern_args? | class_pattern_args)?
          | (
                NAME
                | "str"
                | "int"
                | "float"
                | "list"
                | "tuple"
                | "set"
                | "dict"
                | "bool"
                | "bytes"
                | "any"
                | "type"
            ) class_pattern_args?
          | expression
      )

sequence_pattern ::= "[" (("*" NAME | pattern) ","?)* "]"

tuple_sequence_pattern ::= "(" (("*" NAME | pattern) ","?)* ")"

mapping_pattern ::= "{" (("**" NAME | literal_for_mapping ":" pattern) ","?)* "}"

literal_for_mapping ::= INT | FLOAT | multistring ("-" (INT | FLOAT)?)?

class_pattern_args ::= "(" (((NAME | KWESC_NAME) "=" pattern | pattern) ","?)* ")"

return_stmt ::= "return" expression? ";"

yield_stmt ::= "yield" "from"? expression?

raise_stmt ::= "raise" expression? ("from" expression)? ";"

assert_stmt ::= "assert" expression ("," expression)? ";"

delete_stmt ::= "del" expression ";"

global_stmt ::= "global" NAME ("," NAME)* ";"

nonlocal_stmt ::= "nonlocal" NAME ("," NAME)* ";"

assignment_with_target ::=
    (":" pipe)? (
        "=" (yield_stmt | expression) ("=" (yield_stmt | expression))*
        | (
              (
                  "+="
                  | "-="
                  | "*="
                  | "/="
                  | "//="
                  | "%="
                  | "**="
                  | "@="
                  | "&="
                  | "|="
                  | "^="
                  | "<<="
                  | ">>="
              ) (yield_stmt | expression)
          )?
    ) ";"?

import_stmt ::=
    ("include" | "import") (
        "from" (("." | ELLIPSIS) ELLIPSIS*)?
        (STRING | (NAME | KWESC_NAME) ("." (NAME | KWESC_NAME))*)?
    )? (
        "{" (
            (
                "def"
                | "can"
                | "obj"
                | "class"
                | "enum"
                | "async"
                | STRING
                | "glob"
                | "has"
            ) element_stmt*
            | (("*" | "default" | NAME | KWESC_NAME) ("as" NAME)?)*
        ) "}"
        | (STRING | (NAME | KWESC_NAME) ("." (NAME | KWESC_NAME))*)? ("as" NAME)?
    ) ";"

archetype ::=
    ("@" atomic_chain)* "async"? access_tag (NAME | KWESC_NAME) ("[" type_params "]")?
    ("(" (atomic_chain ("," atomic_chain)*)? ")")? ("{" archetype_member* "}" | ";")

archetype_member ::=
    ";"* STRING? (
        "@" ability
        | "static" ("has" has_stmt | ability)
        | "has" has_stmt
        | "async" ability
        | ("def" | "can" | "override") ability
        | ("obj" | "node" | "edge" | "walker" | "class") archetype
        | "enum" enum
        | "impl" impl_def
        | PYNLINE
        | "with" (("entry" | "exit") "{" code_block_stmts "}")?
        | NAME?
    )

has_stmt ::= "static"? "has" access_tag has_var ("," has_var)* ";"

has_var ::= (NAME | KWESC_NAME) ":" pipe ("=" expression | ("by" "postinit")?)

ability ::=
    ("@" atomic_chain)* "override"? "static"? ("async" "override"? "static"?)?
    access_tag (
        NAME
        | KWESC_NAME
        | "init"
        | "postinit"
        | "root"
        | "super"
        | "self"
        | "props"
        | "here"
        | "visitor"
    )? ("with" expression | func_signature)
    ("{" code_block_stmts "}" | "by" expression ";" | "abs"? ";")

func_signature ::= ("(" func_params? ")")? ("->" pipe)?

func_params ::=
    (
        "*"
        | "/"
        | ("*" | "**")? (NAME | KWESC_NAME | "self") (":" pipe)? ("=" expression)?
    )*

enum ::=
    ("@" atomic_chain)* "enum" access_tag (NAME | KWESC_NAME)
    ("(" (atomic_chain ("," atomic_chain)*)? ")")?
    ("{" (enum_member ","? | PYNLINE | module_code)* "}" | ";")

enum_member ::= NAME ("=" expression)?

test ::= "test" STRING? "{" code_block_stmts "}"

switch_stmt ::= "switch" expression "{" switch_case* "}"

switch_case ::= ("default" | "case" pattern) ":" statement*

global_var ::= "glob" access_tag global_var_assignment ("," global_var_assignment)* ";"

global_var_assignment ::=
    (NAME | KWESC_NAME) (":" pipe)? ("=" expression ("=" expression)*)?

impl_def ::=
    ("@" atomic_chain)* "impl" impl_target_name ("." impl_target_name)* (
        "(" (":" | "self" | ")")? func_signature (atomic_chain ("," atomic_chain)*)? ")"
        | "with" expression
        | func_signature
    )? (
        "{" (NAME | KWESC_NAME)? (
            (NAME | KWESC_NAME) ("(" | "{" | "[" | ")" | "}" | "]")?
            ("=" ("(" | "{" | "[" | ")" | "}" | "]")? ","? | ",")?
        )? ((NAME | KWESC_NAME) ("(" | "{" | "[" | ")" | "}" | "]")? ","?)?
        impl_enum_body code_block_stmts "}"
        | "by" expression ";"
        | ";"
    )

impl_target_name ::=
    NAME | KWESC_NAME | "init" | "postinit" | "entry" | "exit" | "default"

impl_enum_body ::= ((NAME | KWESC_NAME) (":" pipe)? ("=" expression)? ","?)*

sem_def ::= "sem" impl_target_name ("." impl_target_name)* ("=" | "is") STRING ";"?

type_alias ::= "type" access_tag (NAME | KWESC_NAME) ("[" type_params "]")? "=" pipe ";"

type_params ::= NAME (":" pipe)? ("=" pipe)? ("," NAME (":" pipe)? ("=" pipe)?)*

visit_stmt ::= "visit" (":" expression ":")? expression (else_stmt | ";")?

report_stmt ::= "report" expression ";"?
