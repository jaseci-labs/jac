import inspect;
import from types { UnionType }
import from typing { Union, get_args, get_origin, get_type_hints }


glob _NAME_SCHEMAS: dict[str, dict[str, str]] = {
         'str': {'type': 'string'},
         'string': {'type': 'string'},
         'int': {'type': 'integer'},
         'integer': {'type': 'integer'},
         'float': {'type': 'number'},
         'number': {'type': 'number'},
         'bool': {'type': 'boolean'},
         'boolean': {'type': 'boolean'},
         'list': {'type': 'array'},
         'array': {'type': 'array'},
         'dict': {'type': 'object'},
         'object': {'type': 'object'}
     };


def _schema_for_type(
    target: any, schemas: (dict[str, any] | None) = None
) -> dict[str, any];

def _object_schema(target: type, schemas: (dict[str, any] | None)) -> dict[str, any];

def _param_schema(
    param: APIParameter, schemas: (dict[str, any] | None) = None
) -> dict[str, any];

def _body_schema_name(ep: JEndPoint, method: str) -> str;

def _openapi_path(path: str) -> str;

def build_openapi(app: ServingApp) -> dict[str, any];

def swagger_ui_html(openapi_url: str, title: str) -> str;

def register_docs_endpoints(app: ServingApp);
