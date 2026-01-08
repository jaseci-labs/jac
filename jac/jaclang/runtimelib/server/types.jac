"""Type definitions for the server module."""
import from typing { Literal, TypeAlias }

glob JsonValue: TypeAlias = None | str | int | float | bool | <>list['JsonValue'] | <>dict[
         (str, 'JsonValue')
     ],
     StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 500, 503)];

"""Base response container."""
obj Response {
    has status: StatusCode,
        body: JsonValue,
        content_type: str = 'application/json';
}

"""User authentication data."""
obj UserData {
    has username: str,
        token: str,
        root_id: str;
}
