import uuid;
import from typing { Any }
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
        fields: dict[(str, Any)] = {},
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
