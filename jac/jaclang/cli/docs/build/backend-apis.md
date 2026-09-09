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
jac run --no-client api.jac
```

`--no-client` skips all frontend bundling -- a pure JSON API. Walkers are exposed at `POST /walker/<name>`:

```bash
curl -X POST http://localhost:8000/walker/add_task \
  -H "Content-Type: application/json" -d '{"title": "Write docs"}'
```

Interactive API docs are served at `/docs` (Swagger) and a live graph view at `/graph`.

## Scale out to service apps {#service-mesh}

The same code runs as one process *or* as several independently-deployed services -- the only change is an `[apps.<name>]` table in `jac.toml` that makes the provider its own **service app** (`jac create --app math --kind service` writes one). An import of what that app owns compiles to a typed-async bridge stub: the call becomes an RPC you `await`, but the source still reads like a normal import.

```toml
# jac.toml -- the calculator is the default app; math is a file-rooted service app
[project]
name = "calc"
default-app = "calculator"

[apps.calculator]
kind = "service"
entry-point = "calculator_service.jac"

[apps.math]
kind = "service"
entry-point = "math_service.jac"
```

```jac
# math_service.jac  (the provider -- owned by the math app)
def:pub add(a: int, b: int) -> int {
    return a + b;
}

def:pub multiply(a: int, b: int) -> int {
    return a * b;
}
```

```jac
# calculator_service.jac  (the consumer)
import from math_service { add, multiply }

async def:pub dot_product(a: list[int], b: list[int]) -> int {
    result = 0;
    for i in range(len(a)) {
        result = await add(result, await multiply(a[i], b[i]));  # bridged to the math app
    }
    return result;
}
```

One command runs the whole thing. By default the service apps are **colocated** -- loaded into the served app's process, the bridge in-process -- and `--fleet` runs each as its own local process behind the same port:

```bash
jac run --port 8002               # colocated: one process, the boundary still compiled as a cut
jac run --port 8002 --fleet       # each service app in its own process

curl -X POST http://localhost:8002/function/dot_product \
  -H "Content-Type: application/json" -d '{"a": [1,2,3], "b": [4,5,6]}'
```

To split apps across hosts, point each consumer at its providers with `JAC_APP_<APP>_URL` environment variables -- no source change. `jac scale deploy` always deploys a fleet and injects those URLs for you. The boundary is structural, the topology is profile: see [Workspaces & Apps](../reference/apps.md).

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces, persistence, per-user graph isolation
- **Learn the language** → [Jac Fundamentals](../tutorials/language/basics.md) · [Object-Spatial Programming](../tutorials/language/osp.md)
- **Build it for real** → [Local API Server](../tutorials/production/local.md) · [Service Apps](../tutorials/production/microservices.md)
- **Look it up** → [Walker patterns & responses](../reference/language/walker-responses.md) · [Scale reference](../reference/plugins/jac-scale.md)
- **Ship it** → [Kubernetes deployment](../tutorials/production/kubernetes.md) -- `jac scale deploy`

## Going further

- Add a frontend → [Full-stack web apps](fullstack-web.md)
- Add AI endpoints → [AI agents & LLM apps](ai-agents.md)
- Publish backend logic as a library → [Reusable libraries & packages](libraries.md#py-package)
