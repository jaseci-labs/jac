access_tag ::= (COLON (KW_PUB | KW_PRIV | KW_PROT)?)?

module ::= STRING? element_stmt*

expression ::= lambda_expr | concurrent_expr (KW_IF expression KW_ELSE expression)?

concurrent_expr ::= (KW_FLOW | KW_WAIT) walrus_assign | walrus_assign

walrus_assign ::= by_expr (WALRUS_EQ by_expr)?

by_expr ::= pipe (KW_BY by_expr)?

pipe ::= pipe_back (PIPE_FWD pipe_back)*

pipe_back ::= bitwise_or (PIPE_BKWD bitwise_or)*

bitwise_or ::= bitwise_xor (BW_OR bitwise_xor)*

bitwise_xor ::= bitwise_and (BW_XOR bitwise_and)*

bitwise_and ::= shift (BW_AND shift)*

shift ::= logical_or ((LSHIFT | RSHIFT) logical_or)*

logical_or ::= logical_and (KW_OR logical_and)*

logical_and ::= logical_not (KW_AND logical_not)*

logical_not ::= KW_NOT logical_not | compare

compare ::=
    arithmetic (
        (EE | NE | LT | GT | LTE | GTE | KW_IN | KW_IS | KW_NIN | KW_ISN)
        ((EE | NE | LT | GT | LTE | GTE | KW_IN | KW_IS | KW_NIN | KW_ISN) arithmetic)*
    )?

arithmetic ::= term ((PLUS | MINUS) term)*

term ::= power ((STAR_MUL | DIV | FLOOR_DIV | MOD | DECOR_OP) power)*

power ::= factor (STAR_POW power)?

factor ::= (BW_NOT | MINUS | PLUS) factor | connect

connect ::= atomic_pipe (connect_op atomic_pipe)*

edge_op_ref_inline ::=
    (
        ARROW_R
        | ARROW_L
        | ARROW_BI
        | ARROW_R_P1 atom ARROW_R_P2?
        | ARROW_L_P1 atom ARROW_L_P2?
    )?

connect_op ::=
    (
        KW_DELETE edge_op_ref_inline
        | CARROW_R
        | CARROW_R_P1 expression (COLON (expression (EQ expression)?)*)? CARROW_R_P2
        | CARROW_L
        | CARROW_L_P1 expression (COLON (expression (EQ expression)?)*)?
          (CARROW_L_P2 | CARROW_R_P2)?
        | CARROW_BI
    )?

atomic_pipe ::= atomic_pipe_back (A_PIPE_FWD atomic_pipe_back)*

atomic_pipe_back ::= spawn (A_PIPE_BKWD spawn)*

spawn ::= KW_SPAWN unpack | unpack (KW_SPAWN unpack)*

unpack ::= STAR_MUL ref | ref

ref ::= BW_AND await_expr | await_expr

await_expr ::= KW_AWAIT pipe_call | pipe_call

pipe_call ::= (PIPE_FWD | A_PIPE_FWD) atomic_chain | atomic_chain

atomic_chain ::=
    atom (
        DOT (DOT | DOT_FWD | DOT_BKWD)? (
            KW_INIT
            | KW_POST_INIT
            | KW_SELF
            | KW_PROPS
            | KW_SUPER
            | KW_ROOT
            | KW_HERE
            | KW_VISITOR
        )?
        | LPAREN (NULL_OK filter_compr_inner | EQ assign_compr_inner | call_args RPAREN)
        | LSQUARE NULL_OK? LSQUARE expression? (
              COLON COLON expression? (COLON expression?)?
              (COMMA expression? COLON expression? (COLON expression?)?)* RSQUARE
              | (COMMA expression)* RSQUARE
          )
    )

call_args ::= call_arg (COMMA call_arg)*

call_arg ::=
    EQ (KW_SELF | KW_PROPS | KW_SUPER | KW_ROOT | KW_HERE | KW_VISITOR)? expression
    | STAR_POW expression
    | STAR_MUL expression
    | expression (KW_FOR comprehension_clauses)?

filter_compr_inner ::=
    NULL_OK (COLON expression)? COMMA? (compare (COMMA compare)*)? RPAREN

assign_compr_inner ::= EQ (NAME EQ expression (COMMA NAME EQ expression)*)? RPAREN

atom_literal ::= (INT | HEX | BIN | OCT | FLOAT | BOOL | NULL | ELLIPSIS)?

multistring ::= (NAME | STRING | fstring) (NAME | STRING | fstring)*

builtin_type ::=
    (
        TYP_STRING
        | TYP_INT
        | TYP_FLOAT
        | TYP_LIST
        | TYP_TUPLE
        | TYP_SET
        | TYP_DICT
        | TYP_BOOL
        | TYP_BYTES
        | TYP_ANY
        | TYP_TYPE
    )?

special_ref ::=
    (
        KW_SELF
        | KW_SUPER
        | KW_HERE
        | KW_ROOT
        | KW_VISITOR
        | KW_PROPS
        | KW_INIT
        | KW_POST_INIT
        | KW_NODE
        | KW_EDGE
        | KW_WALKER
        | KW_OBJECT
        | KW_CLASS
        | KW_ENUM
    )?

atom ::=
    (
        atom_literal
        | multistring
        | builtin_type
        | special_ref
        | (NAME | KWESC_NAME) NAME?
        | STAR_MUL expression
        | STAR_POW expression
        | LPAREN (
              RPAREN
              | KW_YIELD yield_stmt RPAREN
              | (KW_DEF | KW_CAN | KW_ASYNC) ability RPAREN
              | expression (
                    KW_FOR comprehension_clauses RPAREN
                    | COMMA (expression COMMA?)* RPAREN
                    | RPAREN
                )
          )
        | LSQUARE (
              ARROW_R
              | ARROW_L
              | ARROW_BI
              | ARROW_R_P1
              | ARROW_L_P1
              | RETURN_HINT
              | KW_ASYNC
              | (KW_NODE | KW_EDGE) (
                    ARROW_R
                    | ARROW_L
                    | ARROW_BI
                    | ARROW_R_P1
                    | ARROW_L_P1
                    | RETURN_HINT
                    | NAME
                    | KW_ROOT
                    | KW_SELF
                    | KW_HERE
                    | KW_SUPER
                    | KW_VISITOR
                )?
              | (NAME | KW_ROOT | KW_SELF | KW_HERE | KW_SUPER | KW_VISITOR) (
                    ARROW_R
                    | ARROW_L
                    | ARROW_BI
                    | ARROW_R_P1
                    | ARROW_L_P1
                    | RETURN_HINT
                    | LSQUARE (LSQUARE | RSQUARE)?
                )?
          )? (edge_ref_chain | list_or_compr)
        | LBRACE dict_or_set
        | jsx_element
    )?

fstring ::=
    (
        F_DQ_START
        | F_SQ_START
        | F_TDQ_START
        | F_TSQ_START
        | RF_DQ_START
        | RF_SQ_START
        | RF_TDQ_START
    ) (
        D_LBRACE
        | D_RBRACE
        | LBRACE expression CONV? (COLON (LBRACE expression CONV? RBRACE)?*)? RBRACE
    )*

list_or_compr ::=
    RSQUARE
    | expression (KW_FOR comprehension_clauses RSQUARE | (COMMA expression)* RSQUARE)

edge_ref_chain ::=
    KW_ASYNC? (KW_EDGE | KW_NODE)? (
        (
            NAME
            | KWESC_NAME
            | KW_ROOT
            | KW_SELF
            | KW_HERE
            | KW_SUPER
            | KW_VISITOR
            | LSQUARE
        ) atomic_chain
    )? (
        (ARROW_R | ARROW_L | ARROW_BI) (ARROW_L | ARROW_BI)?
        | RETURN_HINT atom? (COLON (compare (COMMA compare)*)?)? ARROW_R_P2
        | ARROW_L_P1 atom (COLON (compare (COMMA compare)*)?)? ARROW_L_P2
        | ARROW_R_P1 atom ARROW_R_P2
    ) (
        LPAREN (NULL_OK filter_compr_inner | expression RPAREN)
        | (NAME | KWESC_NAME | KW_SELF | KW_ROOT | KW_HERE | KW_SUPER) atomic_chain
    )? RSQUARE

dict_or_set ::=
    RBRACE
    | dict_with_spread
    | expression (
          COLON expression (
              KW_FOR comprehension_clauses RBRACE
              | (COMMA (STAR_POW expression | expression COLON expression))* RBRACE
          )
          | KW_FOR comprehension_clauses RBRACE
          | (COMMA expression)* RBRACE
      )

dict_with_spread ::= (STAR_POW expression | expression COLON expression)* RBRACE

comprehension_clauses ::=
    (KW_ASYNC? KW_FOR atomic_chain KW_IN pipe_call (KW_IF walrus_assign)*)*

lambda_expr ::=
    KW_LAMBDA (LPAREN func_params RPAREN | lambda_params) (RETURN_HINT expression)?
    (COLON expression | LBRACE code_block_stmts RBRACE | expression)

lambda_params ::=
    (
        STAR_MUL? DIV? (STAR_MUL | STAR_POW)? (
            COLON (
                (
                    NAME
                    | TYP_STRING
                    | TYP_INT
                    | TYP_FLOAT
                    | TYP_LIST
                    | TYP_TUPLE
                    | TYP_SET
                    | TYP_DICT
                    | TYP_BOOL
                    | TYP_BYTES
                    | TYP_ANY
                    | TYP_TYPE
                ) (COMMA | EQ | COLON | RETURN_HINT | LBRACE)?
            )? pipe
        )? (EQ expression)?
    )*

jsx_element ::=
    JSX_FRAG_OPEN jsx_children JSX_FRAG_CLOSE
    | JSX_OPEN_START JSX_NAME (DOT JSX_NAME)* jsx_attributes (
          JSX_SELF_CLOSE
          | JSX_TAG_END jsx_children JSX_CLOSE_START JSX_NAME (DOT JSX_NAME)*
            JSX_TAG_END
      )

jsx_opening_element ::=
    JSX_OPEN_START JSX_NAME jsx_attributes (JSX_SELF_CLOSE | JSX_TAG_END)

jsx_attributes ::=
    JSX_NAME (EQ (STRING | LBRACE expression RBRACE)?)?
    | LBRACE ELLIPSIS? expression RBRACE

jsx_children ::= jsx_child*

jsx_child ::= (JSX_TEXT jsx_child? | LBRACE expression RBRACE | jsx_element)?

element_stmt ::=
    (
        SEMI
        | KW_CLIENT (client_block | element_stmt)?
        | KW_SERVER (server_block | element_stmt)?
        | KW_NATIVE (native_block | element_stmt)?
        | import_stmt
        | archetype
        | enum
        | STRING test
        | test
        | STRING (DECOR_OP atomic_chain)* KW_ASYNC* KW_ABSTRACT?
          (archetype | enum | impl_def | ability)
        | STRING enum
        | ability
        | STRING global_var
        | global_var
        | STRING impl_def
        | impl_def
        | sem_def
        | PYNLINE
        | STRING module_code
        | module_code
        | DECOR_OP (DECOR_OP atomic_chain)* KW_ASYNC*
          (ability | enum | impl_def | archetype)
        | KW_ASYNC KW_ASYNC* (ability | archetype)
    )?

client_block ::= KW_CLIENT (LBRACE element_stmt* RBRACE | element_stmt)

server_block ::= KW_SERVER (LBRACE element_stmt* RBRACE | element_stmt)

native_block ::= KW_NATIVE (LBRACE element_stmt* RBRACE | element_stmt)

module_code ::=
    KW_WITH (KW_EXIT | KW_ENTRY)? (COLON NAME)? LBRACE code_block_stmts RBRACE

code_block_stmts ::= (statement SEMI?)*

ctrl_stmt ::= ((KW_BREAK | KW_CONTINUE | KW_SKIP) SEMI | KW_DISENGAGE SEMI)?

statement ::=
    SEMI
    | import_stmt
    | if_stmt
    | while_stmt
    | for_stmt
    | with_stmt
    | try_stmt
    | match_stmt
    | switch_stmt
    | return_stmt
    | KW_YIELD yield_stmt SEMI
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
    | KW_ELIF
    | KW_ELSE
    | KW_EXCEPT
    | KW_FINALLY
    | KW_CASE
    | RETURN_HINT expression LBRACE code_block_stmts RBRACE
    | expression (assignment_with_target | SEMI?)

if_stmt ::= KW_IF expression LBRACE code_block_stmts RBRACE (elif_stmt | else_stmt)?

elif_stmt ::= KW_ELIF expression LBRACE code_block_stmts RBRACE (elif_stmt | else_stmt)?

else_stmt ::= KW_ELSE LBRACE code_block_stmts RBRACE

while_stmt ::= KW_WHILE expression LBRACE code_block_stmts RBRACE else_stmt?

for_stmt ::=
    KW_ASYNC? KW_FOR atomic_chain (
        EQ expression KW_TO pipe KW_BY atomic_chain assignment_with_target? LBRACE
        code_block_stmts RBRACE else_stmt?
        | KW_IN expression LBRACE code_block_stmts RBRACE else_stmt?
    )

try_stmt ::=
    KW_TRY LBRACE code_block_stmts RBRACE (KW_EXCEPT except_handler)* else_stmt?
    (KW_FINALLY LBRACE code_block_stmts RBRACE)?

except_handler ::= KW_EXCEPT expression (KW_AS NAME)? LBRACE code_block_stmts RBRACE

with_stmt ::=
    KW_ASYNC? KW_WITH expression (KW_AS expression)?
    (COMMA expression (KW_AS expression)?)* LBRACE code_block_stmts RBRACE

match_stmt ::= KW_MATCH expression LBRACE (KW_CASE match_case)* RBRACE

match_case ::= KW_CASE pattern (KW_IF expression)? COLON statement*

pattern ::= or_pattern (KW_AS NAME)?

or_pattern ::= single_pattern (BW_OR single_pattern)*

single_pattern ::=
    sequence_pattern
    | tuple_sequence_pattern
    | mapping_pattern
    | BOOL
    | NULL
    | INT
    | FLOAT
    | multistring (
          MINUS (INT | FLOAT)?
          | (DOT (DOT NAME)* class_pattern_args? | class_pattern_args)?
          | (
                TYP_STRING
                | TYP_INT
                | TYP_FLOAT
                | TYP_LIST
                | TYP_TUPLE
                | TYP_SET
                | TYP_DICT
                | TYP_BOOL
                | TYP_BYTES
                | TYP_ANY
                | TYP_TYPE
            ) class_pattern_args?
          | expression
      )

sequence_pattern ::= LSQUARE ((STAR_MUL NAME | pattern) COMMA?)* RSQUARE

tuple_sequence_pattern ::= LPAREN ((STAR_MUL NAME | pattern) COMMA?)* RPAREN

mapping_pattern ::=
    LBRACE ((STAR_POW NAME | literal_for_mapping COLON pattern) COMMA?)* RBRACE

literal_for_mapping ::= INT | FLOAT | multistring (MINUS (INT | FLOAT)?)?

class_pattern_args ::= LPAREN ((EQ EQ pattern | pattern) COMMA?)* RPAREN

return_stmt ::= KW_RETURN expression? SEMI

yield_stmt ::= KW_YIELD KW_FROM? expression?

raise_stmt ::= KW_RAISE expression? (KW_FROM expression)? SEMI

assert_stmt ::= KW_ASSERT expression (COMMA expression)? SEMI

delete_stmt ::= KW_DELETE expression SEMI

global_stmt ::= KW_GLOBAL_REF NAME (COMMA NAME)* SEMI

nonlocal_stmt ::= KW_NONLOCAL NAME (COMMA NAME)* SEMI

assignment_with_target ::=
    (COLON pipe)? (
        EQ EQ*
        | (
              ADD_EQ
              | SUB_EQ
              | MUL_EQ
              | DIV_EQ
              | FLOOR_DIV_EQ
              | MOD_EQ
              | STAR_POW_EQ
              | MATMUL_EQ
              | BW_AND_EQ
              | BW_OR_EQ
              | BW_XOR_EQ
              | LSHIFT_EQ
              | RSHIFT_EQ
          )?
    ) SEMI?

import_stmt ::=
    (KW_INCLUDE | KW_IMPORT)
    (KW_FROM ((DOT | ELLIPSIS) ELLIPSIS?*)? (STRING | (DOT NAME)*)?)? (
        LBRACE ((STAR_MUL | KW_DEFAULT | NAME) (KW_AS NAME)?)* RBRACE
        | (STRING | (DOT NAME)*)? (KW_AS NAME)?
    ) SEMI

archetype ::=
    (DECOR_OP atomic_chain)* KW_ASYNC? KW_ABSTRACT? access_tag NAME
    (LPAREN (atomic_chain (COMMA atomic_chain)*)? RPAREN)?
    (LBRACE archetype_member* RBRACE | SEMI)

archetype_member ::=
    SEMI* STRING? (
        DECOR_OP ability
        | KW_STATIC (KW_HAS has_stmt | ability)
        | KW_HAS has_stmt
        | KW_ASYNC ability
        | (KW_DEF | KW_CAN | KW_OVERRIDE) ability
        | (KW_OBJECT | KW_NODE | KW_EDGE | KW_WALKER | KW_CLASS) archetype
        | KW_ENUM enum
        | KW_IMPL impl_def
        | PYNLINE
        | KW_WITH ((KW_ENTRY | KW_EXIT) LBRACE code_block_stmts RBRACE)?
        | NAME?
    )

has_stmt ::= KW_STATIC? KW_HAS access_tag has_var (COMMA has_var)* SEMI

has_var ::=
    NAME (KW_SELF | KW_PROPS | KW_SUPER | KW_ROOT | KW_HERE | KW_VISITOR)? COLON pipe
    (EQ expression | (KW_BY KW_POST_INIT)?)

ability ::=
    (DECOR_OP atomic_chain)* KW_OVERRIDE? KW_STATIC? (KW_ASYNC KW_OVERRIDE? KW_STATIC?)?
    access_tag (
        KW_INIT
        | KW_POST_INIT
        | KW_ROOT
        | KW_SUPER
        | KW_SELF
        | KW_PROPS
        | KW_HERE
        | KW_VISITOR
    )? (KW_WITH | func_signature)
    (LBRACE code_block_stmts RBRACE | KW_BY expression SEMI | KW_ABSTRACT? SEMI)

func_signature ::= (LPAREN func_params? RPAREN)? (RETURN_HINT pipe)?

func_params ::=
    (
        STAR_MUL
        | DIV
        | (STAR_MUL | STAR_POW)?
          (KW_SELF | (KW_SELF | KW_PROPS | KW_SUPER | KW_ROOT | KW_HERE | KW_VISITOR)?)
          (COLON pipe)? (EQ expression)?
    )*

enum ::=
    (DECOR_OP atomic_chain)* KW_ENUM access_tag NAME
    (LPAREN (atomic_chain (COMMA atomic_chain)*)? RPAREN)?
    (LBRACE (enum_member COMMA? (PYNLINE | KW_WITH module_code))* RBRACE | SEMI)

enum_member ::= NAME (EQ expression)?

test ::= KW_TEST STRING? LBRACE code_block_stmts RBRACE

switch_stmt ::= KW_SWITCH expression LBRACE ((KW_CASE | KW_DEFAULT) switch_case)* RBRACE

switch_case ::= (KW_DEFAULT | KW_CASE pattern) COLON statement*

global_var ::=
    KW_GLOBAL access_tag global_var_assignment (COMMA global_var_assignment)* SEMI

global_var_assignment ::= NAME (COLON pipe)? (EQ expression (EQ expression)*)?

impl_def ::=
    (DECOR_OP atomic_chain)* KW_IMPL impl_target_name (DOT impl_target_name)* (
        LPAREN (KW_SELF | RPAREN)? func_signature (atomic_chain (COMMA atomic_chain)*)?
        RPAREN
        | KW_WITH
        | func_signature
    )? (
        LBRACE COMMA? (
            COLON (LPAREN | LBRACE | LSQUARE | RPAREN | RBRACE | RSQUARE)? (
                EQ (LPAREN | LBRACE | LSQUARE | RPAREN | RBRACE | RSQUARE)? COMMA?
                | COMMA
            )?
        )? (EQ (LPAREN | LBRACE | LSQUARE | RPAREN | RBRACE | RSQUARE)? COMMA?)?
        impl_enum_body code_block_stmts RBRACE
        | KW_BY expression SEMI
        | SEMI
    )

impl_target_name ::= NAME

impl_enum_body ::= ((COLON pipe)? (EQ expression)? COMMA?)*

sem_def ::= KW_SEM impl_target_name (DOT impl_target_name)* (EQ | KW_IS) STRING SEMI?

dotted_name ::= NAME (DOT NAME)*

visit_stmt ::= KW_VISIT (COLON expression COLON)? expression (else_stmt | SEMI)?

report_stmt ::= KW_REPORT expression SEMI?
