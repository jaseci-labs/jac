# Utility APIs

!!! warning "Deprecated"
    **Jac Cloud is deprecated.** Use [jac-scale](../../production/index.md) for new projects.

**Base URL:** `/util`

This section details the Utility APIs, which can be used to facilitate 3rd party Graph Access. Currently, there's two available endpoints, with plans for future expansion to include additional functionalities.

---

## Traverse

This API allows for the traversal of the knowledge graph starting from a specified source.

### Endpoint

`GET /util/traverse`

### Authentication

Bearer Token (Required)

### Query Parameters

| Name         | Type      | Description                                                                                                                                                                              | Default Value       |
| :----------- | :-------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------ |
| `source`     | `string`  | The **JID** of the starting root, node, or edge for the traversal.                                                                                                                       | Current user's root |
| `detailed`   | `boolean` | If `true`, the response will include the archetype's context for each traversed item.                                                                                                    | `false`             |
| `depth`      | `integer` | The maximum number of steps to traverse. Both nodes and edges are considered one step.                                                                                                   | `1`                 |
| `node_types` | `string`  | Can be declared multiple times to filter the traversal results by node type. For example, `node_types=Node1&node_types=Node2` will include only nodes that are `Node1` or `Node2` types. | All node types      |
| `edge_types` | `string`  | Can be declared multiple times to filter the traversal results by edge type. For example, `edge_types=Edge1&edge_types=Edge2` will include only edges that are `Edge1` or `Edge2` types. | All edge types      |

### Sample Request

```bash
curl -X GET "/util/traverse?source=n::68875f383d1e672f517094ff&detailed=true&depth=2&node_types=Node1&node_types=Node2&edge_types=Edge1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Sample Response

```json
{
  "edges": [
    {
      "id": "e::68875f483d1e672f517096a5",
      "source": "n::68875f383d1e672f517094ff",
      "target": "n:A:68875f483d1e672f517096a0"
    },
    {
      "id": "e::68875f483d1e672f517096a2",
      "source": "n:A:68875f483d1e672f517096a0",
      "target": "n:B:68875f483d1e672f517096a1"
    },
    {
      "id": "e::68875f483d1e672f517096a4",
      "source": "n:B:68875f483d1e672f517096a1",
      "target": "n:C:68875f483d1e672f517096a3"
    }
  ],
  "nodes": [
    {
      "id": "n::68875f383d1e672f517094ff",
      "edges": ["e::68875f483d1e672f517096a5"]
    },
    {
      "id": "n:A:68875f483d1e672f517096a0",
      "edges": ["e::68875f483d1e672f517096a2", "e::68875f483d1e672f517096a5"]
    },
    {
      "id": "n:B:68875f483d1e672f517096a1",
      "edges": ["e::68875f483d1e672f517096a2", "e::68875f483d1e672f517096a4"]
    },
    {
      "id": "n:C:68875f483d1e672f517096a3",
      "edges": ["e::68875f483d1e672f517096a4"]
    }
  ]
}
```

---

## Traverse Stream

This API is similar to the `/util/traverse` endpoint but streams the traversal results. It returns data incrementally, pushing results as they are processed for each step of the traversal.

### Endpoint

`GET /util/traverse-stream`

### Authentication

Bearer Token (Required)

### Query Parameters

The query parameters for `/util/traverse-stream` are identical to those for `/util/traverse`:

| Name         | Type      | Description                                                                                                                                                                              | Default Value       |
| :----------- | :-------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------ |
| `source`     | `string`  | The **JID** of the starting root, node, or edge for the traversal.                                                                                                                       | Current user's root |
| `detailed`   | `boolean` | If `true`, the response will include the archetype's context for each traversed item.                                                                                                    | `false`             |
| `depth`      | `integer` | The maximum number of steps to traverse. Both nodes and edges are considered one step.                                                                                                   | `1`                 |
| `node_types` | `string`  | Can be declared multiple times to filter the traversal results by node type. For example, `node_types=Node1&node_types=Node2` will include only nodes that are `Node1` or `Node2` types. | All node types      |
| `edge_types` | `string`  | Can be declared multiple times to filter the traversal results by edge type. For example, `edge_types=Edge1&edge_types=Edge2` will include only edges that are `Edge1` or `Edge2` types. | All edge types      |

### Sample Request

```bash
curl -X GET "/util/traverse-stream?source=n::68875f383d1e672f517094ff&detailed=true&depth=2&node_types=Node1&node_types=Node2&edge_types=Edge1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Sample Streamed Response

The response will be a continuous stream of JSON objects, each representing a "step" in the traversal. The order of `nodes` and `edges` within each step may vary depending on the traversal logic.

```json
{"nodes": [], "edges": [{"id": "e::step1_edge1", "source": "n::start_node", "target": "n::next_node_A"}]}
{"nodes": [{"id": "n::next_node_A", "edges": ["e::step1_edge1"]}], "edges": []}
{"nodes": [], "edges": [{"id": "e::step2_edge1", "source": "n::next_node_A", "target": "n::final_node_B"}]}
{"nodes": [{"id": "n::final_node_B", "edges": ["e::step2_edge1"]}], "edges": []}
... (additional steps will be streamed as the traversal continues)
```
