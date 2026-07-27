# I like to build … Backend APIs & services

HTTP backends with no frontend -- REST APIs whose endpoints come straight from your walkers and functions, deployable as a single service or a mesh of independently-scaled ones. These map to the `service` and `service-mesh` [project kinds](../quick-guide/project-kinds.md).

## Your 5-minute quick win {#service}

Mark a walker `walker:pub` (or a function `def:pub`) and it becomes a REST endpoint automatically -- request bodies map onto the walker's `has` fields, and `report` becomes the JSON response:

```jac
# api.jac
node Task { has title: str; has done: bool = False; }

walker:pub add_task {
    has title: str;
    can create with Root entry {
        task = Task(title=self.title);
        root ++> task;
        report {"id": jid(task), "title": task.title};
    }
}

walker:pub list_tasks {
    can fetch with Root entry {
        report [{"id": jid(t), "title": t.title, "done": t.done}
                for t in [-->][?:Task]];
    }
}
```

```bash
jac start api.jac --no-client
```

`--no-client` skips all frontend bundling -- a pure JSON API. Walkers are exposed at `POST /walker/<name>`:

```bash
curl -X POST http://localhost:8000/walker/add_task \
  -H "Content-Type: application/json" -d '{"title": "Write docs"}'
```

Interactive API docs are served at `/docs` (Swagger) and a live graph view at `/graph`.

## Scale out to a service mesh {#service-mesh}

The same code runs as a monolith *or* as several independently-deployed services -- the only change is the `sv import` keyword. When both modules are server-context, the compiler turns the import into an HTTP client stub: calls become RPCs, but the source still reads like a normal import.

```jac
# math_service.jac  (the provider)
def:pub add(a: int, b: int) -> int {
    return a + b;
}

def:pub multiply(a: int, b: int) -> int {
    return a * b;
}
```

```jac
# calculator_service.jac  (the consumer)
sv import from math_service { add, multiply }

def:pub dot_product(a: list[int], b: list[int]) -> int {
    result = 0;
    for i in range(len(a)) {
        result = add(result, multiply(a[i], b[i]));  # each call is a POST over HTTP
    }
    return result;
}
```

With a `jac.toml` in the directory, one command brings up the whole cluster -- the consumer auto-starts every service it imports from:

```bash
jac start calculator_service.jac --port 8002

curl -X POST http://localhost:8002/function/dot_product \
  -H "Content-Type: application/json" -d '{"a": [1,2,3], "b": [4,5,6]}'
```

To split services across hosts, point each consumer at its providers with `JAC_SV_<MODULE>_URL` environment variables -- no source change. `jac setup microservice --add <file>` records which files become services for production deploys.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces, persistence, per-user graph isolation
- **Learn the language** → [Jac Fundamentals](../tutorials/language/basics.md) · [Object-Spatial Programming](../tutorials/language/osp.md)
- **Build it for real** → [Local API Server](../tutorials/production/local.md) · [Microservices with `sv import`](../tutorials/production/microservices.md)
- **Look it up** → [Walker patterns & responses](../reference/language/walker-responses.md) · [Scale reference](../reference/plugins/jac-scale.md)
- **Ship it** → [Kubernetes deployment](../tutorials/production/kubernetes.md) -- `jac start --scale`

## Going further

- Add a frontend → [Full-stack web apps](fullstack-web.md)
- Add AI endpoints → [AI agents & LLM apps](ai-agents.md)
- Publish backend logic as a library → [Reusable libraries & packages](libraries.md#py-package)
