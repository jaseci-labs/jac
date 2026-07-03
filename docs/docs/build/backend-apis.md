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

The same code runs as a monolith *or* as several independently-deployed services -- the only change is the `sv import` keyword. When both modules are server-context, the compiler turns the import into an HTTP client stub: calls become RPCs, but the source still reads like a normal import. Set `kind = "service-mesh"` and one `jac start` brings up the whole cluster; the consumer auto-starts every service it imports from. Point consumers at remote providers with `JAC_SV_<MODULE>_URL` environment variables -- no source change.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces, persistence, per-user graph isolation
- **Learn the language** → [Jac Fundamentals](../tutorials/language/basics.md) · [Graphs & Walkers](../tutorials/language/osp.md)
- **Build it for real** → [Local API Server](../tutorials/production/local.md) · [Microservices with `sv import`](../tutorials/production/microservices.md)
- **Look it up** → [Walker patterns & responses](../reference/language/walker-responses.md) · [Scale reference](../reference/plugins/jac-scale.md)
- **Ship it** → [Kubernetes deployment](../tutorials/production/kubernetes.md) -- `jac start --scale`

## Going further

- Add a frontend → [Full-stack web apps](fullstack-web.md)
- Add AI endpoints → [AI agents & LLM apps](ai-agents.md)
- Publish backend logic as a library → [Reusable libraries & packages](libraries.md#py-package)
