# Scale Reference

Scale generates REST endpoints from your Jac walkers and functions. Running `jac run` turns every `:pub` or `:priv` walker into an API endpoint on the jac-native HTTP server, with automatic OpenAPI docs, Postgres-native persistence, and built-in authentication.

For production, `jac scale deploy` automates Docker image builds and Kubernetes deployment -- generating Dockerfiles, manifests, and service configurations from your code. This reference covers server startup options, endpoint generation, authentication, database persistence, Kubernetes deployment, and the CLI flags for each mode.

Scale ships **built into `jaclang` core** as the `scale` subsystem (importable as `jaclang.scale`) -- there is no separate `jac-scale` package to install. It arrives with the `jac` binary, so the serving and deployment machinery is always present; only the heavier optional third-party libraries it can use (Kubernetes, Prometheus, cloud storage SDKs, ...) are pulled in per-project, on demand. The database needs nothing extra: the Postgres driver is vendored with the runtime.

## The scale-invariance contract

Scale exists to keep one promise: **your program text does not change with the shape of its deployment.** The property is *scale invariance*: program semantics are invariant under deployment-scale transformation, one user to N users, one machine to M machines, transient to persistent. Delivered, it presents a *single system image*: processes, machines, and users appear to the program as one continuous machine. The program that runs as a script serves as an API and deploys to a cluster --

```bash
jac run main.jac             # one user, one process, local store
jac run main.jac             # N users, one machine, walkers as endpoints
jac scale deploy main.jac    # N users, M machines, Kubernetes
```

-- and the diff between those three configurations is empty. The strata a conventional stack adds at each step (the web framework, the auth middleware, the tenancy filter on every query, the serialization schema, the deployment manifests) encode the *shape of the deployment*, not application meaning, and Scale's position is that deployment shape is a runtime concern, the way garbage collection is a runtime concern. Three mechanisms carry the promise: walkers project as endpoints (a walker's `has` fields and `report`s already form a complete, typed interface description, so there is no route table or client SDK to drift), `root` binds per-caller (each authenticated user's traversals are scoped to their own graph by construction, so isolation is geometry rather than middleware), and persistence follows reachability (transient vs. durable is not a code change).

**What the contract does not hide.** The equivalence is per-user and semantic, not operational -- a deployment with more machines answers with different latencies and fails in different ways, and pretending otherwise is the mistake that sank a generation of RPC systems. So the physics stays visible on purpose:

- **Latency** is excluded from the promise. A traversal that was correct on one machine is correct on twenty; making it *fast* is a placement and caching problem (see [Data & Storage](jac-scale-persistence.md)), not a rewrite.
- **Concurrency conflicts** are handled by a documented rule, not silently: each request runs in one serializable database transaction -- a losing request's work is discarded atomically and replayed against the winner's state (with `on_commit` side effects firing exactly once, for the attempt that wins), or surfaced as a typed conflict error if you configure conflicts to be explicit. See [Concurrent writes](../persistence.md#concurrent-writes-check-then-create-and-convergence).
- **Cost** moves, it doesn't vanish: scaling is paid in machines and operator attention instead of engineering time. The single system image hides the deployment's shape from the program, not the bill from the people running it.

This reference is split across three focused pages, hubbed here. Use the quick reference below to jump to the area you need.

---

## Optional dependencies

Scale's core path -- the HTTP server, JWT auth, Postgres persistence, and CLI flags -- works out of the box with nothing extra to install. Heavier capabilities (Kubernetes deploys, Prometheus metrics, scheduling, cloud object storage) rely on third-party libraries that are **not** bundled into the `jac` binary. You enable them per-project by declaring the matching `[scale.*]` config in `jac.toml` and running `jac install`, which resolves the libraries that intent requires into the project's `.jac/venv`.

```bash
# After configuring the capabilities you need in jac.toml, install the
# resolved dependencies into this project's .jac/venv:
jac install
```

For example, configuring `[scale.kubernetes]` (or using `jac scale deploy`) pulls in `kubernetes`/`docker`; enabling `[scale.monitoring]` pulls in `prometheus-client`; enabling `[scale.scheduler]` pulls in `apscheduler`.

!!! note
    When a feature is used without its dependency present, you get a clear error telling you to declare the relevant `[scale.*]` config and run `jac install`:
    `ImportError: 'kubernetes' is required for this feature. Configure '[scale.deploy]' and run 'jac install'.`

| Capability | What it needs | When you need it |
|-------|-------------|-----------------|
| *(core serving)* | jac-native HTTP server, JWT auth, Postgres persistence | Always available -- ships with `jaclang` |
| Cloud object storage | boto3 (S3), google-cloud-storage (GCS), firebase-admin (Firebase) | Blob storage on a cloud backend |
| Monitoring | prometheus-client | Prometheus `/metrics` endpoint |
| Scheduling | apscheduler | `@schedule(trigger=...)` on walkers/functions |
| Deployment | kubernetes, docker | `jac scale deploy` |

---

## Reference pages

The full Scale reference is organized into three pages:

| Page | Covers |
|------|--------|
| **[HTTP API & Walkers](jac-scale-http.md)** | Starting a server, automatic API endpoint generation, the `@restspec` decorator, middleware walkers, authentication (identity model, registration/login, JWT, SSO, password reset, roles), the admin portal, permissions & access control, webhooks, WebSockets, service apps (cross-app bridging, the `BridgeError` family, the outbox, colocation vs fleet), the emailer, CLI commands, API documentation, and graph visualization. |
| **[Data & Storage](jac-scale-persistence.md)** | Object storage (`store()`, local & S3/GCS-compatible backends), the graph traversal API, async walkers, event streaming, the Postgres database (embedded, external, and Kubernetes-provisioned), and graph builtins. |
| **[Kubernetes & Operations](jac-scale-kubernetes.md)** | Kubernetes deployment (modes, ingress, TLS, autoscaling, storage, images, version pinning, monitoring stack), health checks, Prometheus metrics, Kubernetes secrets, pre-bound ServiceAccount, cross-app shared volumes, service apps in Kubernetes (the deployed fleet), cluster setup, and troubleshooting. |

For end-to-end walkthroughs rather than reference material, see the Deploy tutorials:

- [Local API server](../../tutorials/production/local.md)
- [Service Apps](../../tutorials/production/microservices.md)
- [Kubernetes](../../tutorials/production/kubernetes.md)

---

## Library Mode

Teams preferring pure Python syntax can drive all of Scale through `jaclang.lib` instead of `.jac` files. See [Library Mode](../language/library-mode.md) for the full API reference and examples.

---

## Related Resources

- [Local API Server Tutorial](../../tutorials/production/local.md)
- [Kubernetes Deployment Tutorial](../../tutorials/production/kubernetes.md)
- [Backend Integration Tutorial](../../tutorials/fullstack/backend.md)
