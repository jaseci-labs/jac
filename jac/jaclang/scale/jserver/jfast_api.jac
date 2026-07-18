import inspect;
import logging;
import uvicorn;
import from collections.abc { Callable }
import from typing { Any, Optional, TypeAlias, get_type_hints }
import from fastapi {
    Body,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    Path,
    Query,
    Request,
    UploadFile
}
import from fastapi.responses { Response, JSONResponse }
import from pydantic { BaseModel, Field, create_model }
import from .jserver { APIParameter, HTTPMethod, JEndPoint, JServer, ParameterType }
import from jaclang.runtimelib.transport { TransportResponse }
import from jaclang.jac0core.runtime { JacRuntime, JacRuntimeInterface }

glob logger = logging.getLogger(__name__),
     EndpointResponse: TypeAlias = Response | BaseModel | dict[(str, object)] | list[
         object
     ] | str | `bytes | None;

obj ParameterHandler {
    has type_converter: JFastApiServer;

    def generate_param_string(param: APIParameter) -> str;
    def get_type(param: APIParameter) -> type[any] {
        return self.type_converter._get_python_type(param.data_type);
    }

    def get_type_name(param: APIParameter) -> str {
        return self.get_type(param).__name__;
    }
}

obj PathParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

obj QueryParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

obj HeaderParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

obj FileParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

obj FormBodyParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

obj JSONBodyParameterHandler(ParameterHandler) {
    has body_params: list[APIParameter];

    def generate_body_model -> (type[BaseModel] | None);
}

class JFastApiServer(JServer[FastAPI]) {
    has _user_manager: any | None = None;

    def set_user_manager(self: JFastApiServer, user_manager: any) -> None;
    def init(
        self: JFastApiServer,
        endpoints: (list[JEndPoint] | None) = None,
        app: (FastAPI | None) = None
    ) -> None;

    def _get(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _post(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _put(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _patch(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _delete(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _route_priority(
        self: JFastApiServer, endpoint: JEndPoint
    ) -> tuple[int, int, int, str];

    def execute(self: JFastApiServer) -> None;
    def create_server(self: JFastApiServer) -> FastAPI;
    def _create_fastapi_route(
        self: JFastApiServer, method: HTTPMethod, endpoint: JEndPoint
    ) -> None;

    def _get_default_status_code(self: JFastApiServer, method: HTTPMethod) -> int;
    def _create_endpoint_function(
        self: JFastApiServer,
        callback: Callable[(..., Any)],
        parameters: list[APIParameter],
        dependencies: list[any],
        request_model: (type[BaseModel] | None) = None,
        forward_undeclared_query_params: bool = True
    ) -> Callable[..., any];

    def _get_python_type(self: JFastApiServer, type_string: str) -> type[any];
    def _resolve_type(
        self: JFastApiServer, type_string: str, type_obj: any = None
    ) -> any;

    def _build_pydantic_model(self: JFastApiServer, jac_cls: any) -> type[BaseModel];
    def get_app(self: JFastApiServer) -> FastAPI;
    def run_server(
        self: JFastApiServer,
        host: str = '0.0.0.0',
        port: int = 8000,
        max_retries: int = 10
    ) -> None;
}
