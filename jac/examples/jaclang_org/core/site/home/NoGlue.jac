glob _TODO_LINES: list[str] = [
         "node Todo {",
         "    has title: str;",
         "}",
         "",
         "def:pub add_todo(title: str) -> Todo {",
         "    todo = Todo(title=title);",
         "    root ++> todo;",
         "    return todo;",
         "}",
         "",
         "def:pub get_todos -> list[Todo] {",
         "    return [root-->][?:Todo];",
         "}",
         "",
         "def:pub todo_app -> JsxElement {",
         "    has todos: list[Todo] = [];",
         "",
         "    async can with entry {",
         "        todos = await get_todos();",
         "    }",
         "",
         "    return <ul>{[<li key={jid(t)}>{t.title}</li> for t in todos]}</ul>;",
         "}",

     ],
     _GLUE: list[dict[str, any]] = [
         {
             "title": "A node is a persistent type",
             "from": 1,
             "to": 3,
             "body": "Anything reachable from root persists, with no schema or migrations.",
             "replaces": ["schema.sql", "migrations/", "models.py (ORM)"]
         },
         {
             "title": "`def:pub` is an API endpoint",
             "from": 5,
             "to": 13,
             "body": "A public function becomes a typed, validated HTTP endpoint with an OpenAPI entry.",
             "replaces": ["routes.py", "request validators", "openapi.yaml"]
         },
         {
             "title": "Connecting a node is the write",
             "from": 7,
             "to": 7,
             "body": "`root ++> todo` saves under the caller's root, so per-user isolation comes from the graph.",
             "replaces": ["db session", "INSERT INTO …", "WHERE user_id = ?"]
         },
         {
             "title": "Components compile to React",
             "from": 15,
             "to": 23,
             "body": "The UI compiles to React right beside the logic it uses.",
             "replaces": ["frontend repo", "package.json", "types.ts (duplicated)"]
         },
         {
             "title": "A remote call is a function call",
             "from": 19,
             "to": 19,
             "body": "`await get_todos()` is an RPC whose request, serialization and types are generated.",
             "replaces": ["api/client.ts", "fetch wrapper", "JSON serializers"]
         },
         {
             "title": "Deployment is a command",
             "from": 0,
             "to": -1,
             "body": "`jac scale deploy` ships the same program to Kubernetes with derived manifests.",
             "replaces": ["Dockerfile", "docker-compose.yml", "k8s/*.yaml"]
         },

     ];

def:pub GlueMap -> JsxElement;

def:pub NoGlue -> JsxElement;
