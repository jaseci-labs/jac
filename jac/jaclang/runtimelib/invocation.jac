import uuid;
import from jaclang.runtimelib.transport { ErrorInfo }
import type from jaclang.runtimelib.transport { TransportResponse }
import type from jaclang.runtimelib.server {
    ExecutionManager,
    ModuleIntrospector,
    UserManager
}


enum InvocationKind { WALKER = "walker", FUNCTION = "function" }


obj InvocationRequest {
    has kind: InvocationKind,
        name: str,
        fields: dict[str, any] = {},
        node_id: (str | None) = None,
        token: str = "",
        resolved_user: (str | None) = None,
        identity_prevalidated: bool = False;
}


obj InvocationResult {
    has ok: bool = True,
        data: any = None,
        error: (ErrorInfo | None) = None,
        http_status: int = 200,
        request_id: str = "",
        is_stream: bool = False,
        stream: any = None;

    static def from_transport(response: TransportResponse) -> InvocationResult;
    def to_transport -> TransportResponse;
    def to_body -> dict;
}

obj ValidationOutcome {
    has error: (str | None) = None,
        fields: dict = {};
}


obj InvocationDispatcher {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;

    async def invoke(request: InvocationRequest) -> InvocationResult;
}


obj PreparedInvocationRuntime {
    has dispatcher: InvocationDispatcher,
        introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager,
        module_name: str = "",
        _prior_ctx: any = None;

    def close;
}


def prepare_invocation_runtime(
    jac_file: str, graph_path: str
) -> PreparedInvocationRuntime;


def _invoke_sync(
    dispatcher: InvocationDispatcher, request: InvocationRequest
) -> InvocationResult;


def new_request_id -> str {
    return uuid.uuid4().hex[:12];
}


def coerce_scalar(type_name: str, value: any) -> tuple[bool, any] {
    core = type_name.strip().replace("typing.", "");
    while core.startswith("(") and core.endswith(")") {
        core = core[1:-1];
    }
    core = core.replace(" ", "");
    if core.startswith("Optional[") and core.endswith("]") {
        core = core[9:-1];
    }
    if core.startswith("Union[") and core.endswith("]") {
        parts = [
            p
            for p in core[6:-1].split(",")
            if p not in ("", "None", "NoneType")
        ];
        if len(parts) == 1 {
            core = parts[0];
        }
    }
    if "|" in core {
        parts = [
            p
            for p in core.split("|")
            if p not in ("", "None", "NoneType")
        ];
        if len(parts) == 1 {
            core = parts[0];
        }
    }

    if value is None {
        return (True, value);
    }
    if core == "int" {
        if isinstance(value, bool) {
            return (True, value);
        }
        if isinstance(value, int) {
            return (True, value);
        }
        try {
            return (True, int(value));
        } except Exception {
            return (False, value);
        }
    }
    if core == "float" {
        if isinstance(value, bool) {
            return (True, value);
        }
        if isinstance(value, (int, float)) {
            return (True, float(value));
        }
        try {
            return (True, float(value));
        } except Exception {
            return (False, value);
        }
    }
    if core == "bool" {
        if isinstance(value, bool) {
            return (True, value);
        }
        if isinstance(value, str) {
            low = value.strip().lower();
            if low in ("true", "1", "yes", "on") {
                return (True, True);
            }
            if low in ("false", "0", "no", "off") {
                return (True, False);
            }
            return (False, value);
        }
        if isinstance(value, int) {
            return (True, bool(value));
        }
        return (False, value);
    }
    return (True, value);
}
