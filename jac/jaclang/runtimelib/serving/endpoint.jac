import from enum { StrEnum }


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
        kind: ParameterType = ParameterType.QUERY,
        data_type: str = 'str',
        type_obj: any = None,
        required: bool = True,
        default_value: any = None,
        description: str = '';
}

obj JEndPoint {
    has method: HTTPMethod,
        path: str,
        callback: Callable[..., any],
        parameters: (list[APIParameter] | None) = None,
        response_model: any = None,
        request_model: any = None,
        status_code: (int | None) = None,
        media_type: (str | None) = None,
        tags: (list[str] | None) = None,
        summary: (str | None) = None,
        description: (str | None) = None,
        requires_auth: bool = False,
        forward_undeclared_query_params: bool = True,
        include_in_schema: bool = True,
        callback_spec: any = None;
}

obj WSEndPoint {
    has path: str,
        handler: Callable[..., any],
        summary: (str | None) = None;
}
