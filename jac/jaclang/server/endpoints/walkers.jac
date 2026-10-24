import json;
import logging;
import from inspect { isgenerator }
import from typing { AsyncGenerator, get_type_hints }

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def _unauthorized -> TransportResponse;


def _unavailable(kind: str, name: str) -> TransportResponse;


def request_caller(server: JacAPIServer, request: Request) -> (str | None);


def idempotency_key(request: Request, username: str, app: str, target: str) -> str;


def _stream(result: any) -> StreamingResponse;


def _failure(result: dict[str, any], fallback: str) -> TransportResponse;


def _single_line(text: str) -> bool;


def _raw_response(
    request: Request, payload: any, declared_media_type: str
) -> (Response | TransportResponse);


def _param_kind(
    field_name: str,
    field_type: str,
    path_names: list[str],
    method: HTTPMethod,
    type_obj: any = None
) -> ParameterType;


def walker_parameters(
    server: JacAPIServer,
    walker_name: str,
    walker_cls: type,
    invoke_on_root: bool,
    method: HTTPMethod = HTTPMethod.POST
) -> list[APIParameter];


def walker_callback(
    server: JacAPIServer, walker_name: str
) -> Callable[..., (TransportResponse | StreamingResponse | Response)];


def register_walker_endpoints(server: JacAPIServer);


def _walker_parameter_source(
    server: JacAPIServer, walker_name: str, invoke_on_root: bool, method: HTTPMethod
) -> Callable[[], list[APIParameter]];


def function_parameters(
    server: JacAPIServer,
    func_name: str,
    func_obj: Callable,
    method: HTTPMethod = HTTPMethod.POST
) -> list[APIParameter];


def function_callback(
    server: JacAPIServer, func_name: str, restspec: any
) -> Callable[..., (TransportResponse | StreamingResponse | Response)];


def register_function_endpoints(server: JacAPIServer);


def _function_parameter_source(
    server: JacAPIServer, func_name: str, method: HTTPMethod
) -> Callable[[], list[APIParameter]];
