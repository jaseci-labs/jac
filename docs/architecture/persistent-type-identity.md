# Application persistence identity

One logical application uses one database across its services. A service call
retains the database binding and the user's root ID. Services have separate
execution contexts, transactions and runtime classes; they read the same committed
graph through their own compiled schemas. A user's root is a node in that database,
not a separate database.

Persistent types are identified by application namespace, project-relative logical
module and declaration name. Importing the same model into multiple services
shares its persistent identity automatically. There are no domain declarations,
participant lists or schema-owner gates. Different modules remain different schemas,
even when they declare classes with the same name.

The namespace defaults to the project name. An optional stable override is useful
when deployment project names differ:

```toml
[persistence]
namespace = "com.example.accounts"
```

The compiler stamps each module with its namespace and logical module name. The
Python emitter and prepared manifest retain these facts, including in sealed
artifacts. Runtime resolution reads compiled metadata without reinterpreting
project configuration. The durable module spelling is `jac:` followed by the
compact JSON array `[namespace, logical-module]`; the class name completes the
identity. Python's runtime module names remain private and may differ by service.
SQL type filters, ancestry indexes, fingerprints and rename aliases use the same
durable identity.

A session resolves stored types through its service's prepared module manifest.
Missing schemas in the application's namespace fail explicitly without quarantining
valid data. Types from an unrelated application namespace remain foreign: reads
preserve their rows and references. Corrupt payload handling remains separate.
Unscoped deserialization must identify a unique loaded class; callers can select
`resolution_scope(prepared_application)` to resolve a specific service's classes.

Database selection belongs to application startup. Embedded database names use the
project namespace and canonical project directory, independent of service entry
filenames or subdirectories. Standalone files without a project remain standalone
applications. An explicit database URL selects the deployment database. Provider
sessions are created from the already-bound store through `new_session`, retaining
its connection settings and pool while owning their transaction and identity map.
They do not rediscover a database from the provider's source path. Service calls do
not share uncommitted mutations or create cross-service transactions.

## Clean break

Rebuild source, sealed and exported artifacts. Legacy `_jac_app_<path-hash>` type
names require an explicit migration; stripping prefixes could merge unrelated
schemas. Existing deployments whose service entry paths selected separate databases
must consolidate their data into the application's selected database before serving.
This change does not silently move rows or merge databases at startup.

For a known old type name, use the existing `@archetype_alias("old.module.Type")`
or `schema_was` declaration. Aliases target durable identities and resolve to the
consuming service's class. Conflicting mappings and cycles are rejected. Rewrite
affected rows, including nested persisted values, before removing migration aliases.
Changing the namespace or logical declaration name is a schema rename; relocating
an application does not change its type identity.
