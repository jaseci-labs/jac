"""Implementation for transform constructs."""

"""Initialize alert."""
impl Alert.init(
    self: Alert, msg: str, loc: CodeLocInfo, from_pass: type[Transform]
) -> None {
    self.msg = msg;
    self.loc: CodeLocInfo = loc;
    self.from_pass: type[Transform] = from_pass;
}

"""Return string representation of alert."""
impl Alert.__str__(self: Alert) -> str {
    return f"{self.loc.mod_path}, line {self.loc.first_line}, col {self.loc.col_start}: {self.msg}";
}

"""Return string representation of alert."""
impl Alert.__repr__(self: Alert) -> str {
    return self.as_log();
}

"""Return the alert as a single line log as opposed to the pretty print."""
impl Alert.as_log(self: Alert, *, colors: bool = False) -> str {
    import from jaclang.jac0core.helpers { ANSIColors }
    file_path: str = self.loc.mod_path;
    if (file_path == '') {
        return self.msg;
    }
    line: int = self.loc.first_line;
    column: int = self.loc.col_start;
    msg = self.msg if not colors else f"{ANSIColors.RED}{self.msg}{ANSIColors.END}";
    return f"{file_path}:{line}:{column} {msg}";
}

"""Pretty prints the Alert to show the alert with source location."""
impl Alert.pretty_print(self: Alert, *, colors: bool = False) -> str {
    import from jaclang.jac0core.helpers { pretty_print_source_location }
    pretty_dump = pretty_print_source_location(
        self.loc.mod_path,
        self.loc.orig_src.code,
        self.loc.first_line,
        self.loc.pos_start,
        self.loc.pos_end,
        colors=colors
    );
    if (pretty_dump != '') {
        pretty_dump = '\n' + pretty_dump;
    }
    return (self.as_log(colors=colors) + pretty_dump);
}

"""Initialize pass."""
impl BaseTransform.init(
    self: BaseTransform,
    ir_in: T_in,
    prog: JacProgram,
    cancel_token: (Event | None) = None
) -> None {
    self.logger = logging.getLogger(self.__class__.__name__);
    self.errors_had: list[Alert] = [];
    self.warnings_had: list[Alert] = [];
    self.prog = prog;
    self.time_taken = 0.0;
    self.ir_in: T_in = ir_in;
    self.cancel_token = cancel_token;
    self.pre_transform();
    self.ir_out: T_out = self.timed_transform(ir_in=ir_in);
    self.post_transform();
}

"""Transform with time tracking."""
impl BaseTransform.timed_transform(self: BaseTransform, ir_in: T_in) -> T_out {
    start_time = time.time();
    ir_out = self.transform(ir_in=ir_in);
    self.time_taken = time.time() - start_time;
    return ir_out;
}

"""Pre-transform hook."""
impl BaseTransform.pre_transform(self: BaseTransform) -> None {
    ;
}

"""Post-transform hook."""
impl BaseTransform.post_transform(self: BaseTransform) -> None {
    ;
}

"""Transform interface."""
@ abstractmethod
impl BaseTransform.transform(self: BaseTransform, ir_in: T_in) -> T_out {
    ;
}

"""Log info."""
impl BaseTransform.log_info(self: BaseTransform, msg: str) -> None {
    self.logger.info(msg);
}

"""Check if the pass has been canceled."""
impl BaseTransform.is_canceled(self: BaseTransform) -> bool {
    return ((self.cancel_token is not None) and self.cancel_token.is_set());
}

"""Initialize pass."""
impl Transform.init(
    self: Transform, ir_in: T, prog: JacProgram, cancel_token: (Event | None) = None
) -> None {
    self.cur_node: UniNode = ir_in;
    super.init(ir_in, prog, cancel_token);
}

"""Pass Error."""
impl Transform.log_error(
    self: Transform, msg: str, node_override: (UniNode | None) = None
) -> None {
    alrt = Alert(
        msg,
        self.cur_node.loc if not node_override else node_override.loc,
        self.__class__
    );
    self.errors_had.append(alrt);
    self.prog.errors_had.append(alrt);
}

"""Pass Error."""
impl Transform.log_warning(
    self: Transform, msg: str, node_override: (UniNode | None) = None
) -> None {
    alrt = Alert(
        msg,
        self.cur_node.loc if not node_override else node_override.loc,
        self.__class__
    );
    self.warnings_had.append(alrt);
    self.prog.warnings_had.append(alrt);
}

"""Pass Error."""
impl Transform.ice(
    self: Transform, msg: str = 'Something went horribly wrong!'
) -> RuntimeError {
    self.log_error(f"ICE: Pass {self.__class__.__name__} - {msg}");
    return RuntimeError(
        f"Internal Compiler Error: Pass {self.__class__.__name__} - {msg}"
    );
}
