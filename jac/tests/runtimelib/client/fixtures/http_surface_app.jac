"""`sv` backend fixture for the http_surface cross-transport bridge tests.

Exercises the route surface that `inprocess_dispatch.forward` now uses:

- `greet` / `add`   -- default POST /walker/{name} and /function/{name} routes.
- `PingWalker`      -- @restspec GET with a custom path (custom verb + path).
- `SearchWalker`    -- @restspec GET whose fields bind from the query string
                       (with int coercion) instead of a JSON body.
- `UpdateThing`     -- @restspec POST with a path parameter + JSON body.
- `stream_numbers`  -- a streaming function (blocked on the sv bridge).
"""

import from jaclang.runtimelib.builtin { restspec }
import from http { HTTPMethod }


walker:pub greet {
    has name: str = "world";

    can run with Root entry {
        report {"greeting": f"hello {self.name}"};
    }
}


def:pub add(a: int, b: int) -> int {
    return a + b;
}


"""GET walker on a custom @restspec path -- custom verb + custom path."""
@restspec(method=HTTPMethod.GET, path="/custom/ping")
walker:pub PingWalker {
    can run with Root entry {
        report {"pong": True, "path": "/custom/ping"};
    }
}


"""GET walker whose fields bind from the query string (age coerces to int)."""
@restspec(method=HTTPMethod.GET)
walker:pub SearchWalker {
    has name: str,
        age: int;

    can run with Root entry {
        report {
            "name": self.name,
            "age": self.age,
            "age_type": type(self.age).__name__
        };
    }
}


"""POST walker with a path parameter plus a JSON body field."""
@restspec(method=HTTPMethod.POST, path="/things/{thing_id}/update")
walker:pub UpdateThing {
    has thing_id: str,
        label: str = "";

    can run with Root entry {
        report {"thing_id": self.thing_id, "label": self.label};
    }
}


"""Streaming function: the sv bridge blocks streaming with a 500."""
def:pub stream_numbers(n: int = 3) -> any {
    for i in range(n) {
        yield {"n": i};
    }
}
