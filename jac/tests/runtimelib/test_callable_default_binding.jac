"""Callable introspection keeps raw parameter defaults for endpoint binding.

A `def:pub` endpoint builds its APIParameters from
`ModuleIntrospector.introspect_callable`, and `bind_parameters` injects a
parameter's `default_value` verbatim when the request omits it. If the
introspected default were stringified, `= None` would bind the string 'None',
`= 40` the string '40', and so on. Walker introspection already stores the
raw default; callables must behave the same way.
"""

import from jaclang.server.endpoints.walkers { function_parameters }
import from jaclang.server.server { ModuleIntrospector }
import from jaclang.server.serving.coerce { bind_parameters }
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}

obj _StubServer {
    has introspector: ModuleIntrospector;
}

def _optional_defaults_fn(
    name: str,
    thread_id: (str | None) = None,
    limit: int = 40,
    flag: bool = True,
    tag: str = "x"
) -> dict[str, any] {
    return {
        'name': name,
        'thread_id': (type(thread_id).__name__, thread_id),
        'limit': (type(limit).__name__, limit),
        'flag': (type(flag).__name__, flag),
        'tag': (type(tag).__name__, tag)
    };
}

def _binding_endpoint -> tuple[JEndPoint, any] {
    server: any = _StubServer(
        introspector=ModuleIntrospector("callable_defaults", None)
    );
    ep = JEndPoint(
        method=HTTPMethod.POST,
        path='/function/probe',
        callback=_optional_defaults_fn,
        parameters=function_parameters(
            server, 'probe', _optional_defaults_fn, method=HTTPMethod.POST
        )
    );
    return (ep, _optional_defaults_fn);
}

test "callable introspection reports raw parameter defaults" {
    introspector = ModuleIntrospector("callable_defaults", None);
    params = introspector.introspect_callable(_optional_defaults_fn)['parameters'];
    assert params['name']['required'];
    assert params['name']['default'] is None;
    assert params['thread_id']['default'] is None;
    assert params['limit']['default'] == 40
        and isinstance(params['limit']['default'], int);
    assert params['flag']['default'] is True;
    assert params['tag']['default'] == 'x';
}

test "omitted optional arguments bind their typed defaults" {
    (ep, fn) = _binding_endpoint();
    kwargs = bind_parameters(ep, Request(body=b'{"name": "a"}'), {'name': 'a'});
    result = fn(**kwargs);
    assert result['name'] == 'a';
    assert result['thread_id'] == ('NoneType', None) , result;
    assert result['limit'] == ('int', 40) , result;
    assert result['flag'] == ('bool', True) , result;
    assert result['tag'] == ('str', 'x') , result;
}

test "explicit arguments still coerce to the declared types" {
    (ep, fn) = _binding_endpoint();
    body = {'name': 'a', 'thread_id': 't-1', 'limit': '7', 'flag': 'false'};
    kwargs = bind_parameters(ep, Request(body=b''), body);
    result = fn(**kwargs);
    assert result['thread_id'] == ('str', 't-1') , result;
    assert result['limit'] == ('int', 7) , result;
    assert result['flag'] == ('bool', False) , result;
}
