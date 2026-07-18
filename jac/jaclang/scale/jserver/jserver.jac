import from abc { ABC, abstractmethod }
import from collections.abc { Callable }
import from dataclasses { dataclass }
import from typing { Any, Generic, TypeVar }
import from pydantic { BaseModel }
import from enum { StrEnum }

glob T = TypeVar('T');

class HTTPMethod(StrEnum) {
    has GET: str = 'GET',
        POST: str = 'POST',
        PUT: str = 'PUT',
        PATCH: str = 'PATCH',
        DELETE: str = 'DELETE';
}

class ParameterType(StrEnum) {
    has QUERY: str = 'query',
        PATH: str = 'path',
        BODY: str = 'body',
        HEADER: str = 'header',
        FILE: str = 'file';
}

obj APIParameter {
    has name: str,
        `type: ParameterType = ParameterType.QUERY,
        data_type: str = 'str',
        type_obj: any = None,
        required: bool = True,
        `default: any = None,
        description: str = '';
}

obj JEndPoint {
    has method: HTTPMethod,
        path: str,
        callback: Callable[(..., Any)],
        parameters: (list[APIParameter] | None) = None,
        response_model: (type[BaseModel] | None) = None,
        request_model: (type[BaseModel] | None) = None,
        tags: (list[str] | None) = None,
        summary: (str | None) = None,
        description: (str | None) = None,
        forward_undeclared_query_params: bool = True;
}

class JServer(ABC, Generic[T]) {
    def init(self: JServer, end_points: list[JEndPoint]) -> None;
    def add_endpoint(self: JServer, endpoint: JEndPoint) -> None;
    def execute(self: JServer) -> None;
    @abstractmethod
    def _get(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

    @abstractmethod
    def _post(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

    @abstractmethod
    def _put(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

    @abstractmethod
    def _patch(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

    @abstractmethod
    def _delete(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

    @abstractmethod
    def create_server(self: JServer) -> T { }

    @abstractmethod
    def run_server(
        self: JServer, host: str = 'localhost', port: int = 8000, max_retries: int = 10
    ) { }
}
