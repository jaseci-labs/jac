glob OVERFLOW_MESSAGE: str = "integer overflow",
     ZERO_DIVISION_MESSAGE: str = "integer division or modulo by zero",
     FLOAT_ZERO_DIVISION_MESSAGE: str = "float division by zero",
     FLOAT_ZERO_MODULO_MESSAGE: str = "float modulo by zero",
     FLOAT_ZERO_FLOOR_MESSAGE: str = "float floor division by zero",
     AUG_OPERATORS: dict[str, str] = {
         "ADD_EQ": "PLUS",
         "SUB_EQ": "MINUS",
         "MUL_EQ": "STAR_MUL",
         "DIV_EQ": "DIV",
         "FLOOR_DIV_EQ": "FLOOR_DIV",
         "MOD_EQ": "MOD",
         "BW_AND_EQ": "BW_AND",
         "BW_OR_EQ": "BW_OR",
         "BW_XOR_EQ": "BW_XOR"
     },
     COMPARE_OPERATORS: dict[str, str] = {
         "EE": "eq",
         "NE": "ne",
         "LT": "lt",
         "GT": "gt",
         "LTE": "le",
         "GTE": "ge"
     };

obj MirLoopTarget {
    has head: MirBlock,
        after: MirBlock;
}

obj MirFnState {
    has fn: MirFunction,
        b: MirBuilder,
        locals: dict[int, MirValue] = {},
        loops: list[MirLoopTarget] = [];
}

obj MirDecl {
    has ability: uni.Ability,
        symbol: str,
        ret: MirType,
        params: list[MirType] = [];
}

obj MirLowering {
    has prog: JacProgram,
        module: uni.Module,
        mir: MirModule,
        decls: dict[int, MirDecl] = {},
        order: list[int] = [],
        refusals: dict[str, list[NativeRefusal]] = {},
        state: (MirFnState | None) = None;

    def lower -> MirModule;
    def module_abilities -> list[uni.Ability];
    def declare(ab: uni.Ability);
    def symbol_of(ab: uni.Ability) -> str;
    def name_of(ab: uni.Ability) -> str;
    def ability_sym(ab: uni.Ability) -> uni.Symbol;
    def lower_function(decl: MirDecl) -> (MirFunction | None);
    def st -> MirFnState;
    def builder -> MirBuilder;
    def symbol_type(sym: (uni.Symbol | None), site: uni.UniNode) -> MirType;
    def expr_type(nd: uni.Expr) -> MirType;
    def lower_body(stmts: Sequence[uni.UniNode]);
    def lower_stmt(nd: uni.UniNode);
    def lower_assignment(nd: uni.Assignment);
    def store_name(target: uni.Name, value: MirValue);
    def local_slot(sym: (uni.Symbol | None), site: uni.UniNode) -> MirValue;
    def lower_return(nd: uni.ReturnStmt);
    def lower_if(nd: (uni.IfStmt | uni.ElseIf));
    def lower_else(nd: (uni.ElseStmt | uni.ElseIf | None), done: MirBlock);
    def lower_while(nd: uni.WhileStmt);
    def lower_ctrl(nd: uni.CtrlStmt);
    def lower_expr(nd: uni.UniNode) -> MirValue;
    def lower_name(nd: uni.Name) -> MirValue;
    def lower_binary(nd: uni.BinaryExpr) -> MirValue;
    def arith(op: str, left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue;
    def lower_compare(nd: uni.CompareExpr) -> MirValue;
    def compare_values(
        op: str, left: MirValue, right: MirValue, site: uni.UniNode
    ) -> MirValue;

    def lower_unary(nd: uni.UnaryExpr) -> MirValue;
    def lower_bool(nd: uni.BoolExpr) -> MirValue;
    def lower_call(nd: uni.FuncCall) -> MirValue;
    def truthy(value: MirValue, site: uni.UniNode) -> MirValue;
    def coerce(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue;
    def unify_numeric(
        left: MirValue, right: MirValue, site: uni.UniNode
    ) -> tuple[MirValue, MirValue];

    def raise_if(cond: MirValue, exception: str, message: str);
}
