# Persistent graph identity

Python module names identify executable module instances. They are not durable
schema names: prepared applications isolate globals under private namespaces,
and sealed/exported applications can relocate those instances.

The project reader validates `[persistence]` once. The application-context pass
stamps each module with namespace, app, domain, logical module and schema owner.
The Python emitter and prepared manifest retain these facts. Runtime resolution
reads executable metadata only; it never reinterprets project configuration.

By default a module belongs to `app:<app-name>`. Explicit domains allow several
apps to use one persistent schema while keeping separate classes and globals:

```toml
[persistence]
namespace = "com.example.accounts"

[persistence.domains.profiles]
owner = "accounts"
apps = ["accounts", "reader"]
modules = ["shared.profiles"]
```

Module names are exact project-relative dotted names, not directory claims or
wildcards. Every module has at most one domain. The owner must be a participant;
all participants must be declared apps. An undeclared consumer fails compilation
with E5113. The namespace defaults to the project name. Choose a unique explicit
namespace when independent projects use the same database.

The durable module spelling is `jac:` followed by the compact JSON array
`[namespace, domain, logical-module]`. The class name completes the identity.
The existing wire fields `__module__` and `__type__` hold these logical names;
Python's actual `__module__` is unchanged. SQL type filters and inheritance
indexes use the same qualified identity. Schema fingerprints use logical type
names rather than runtime module prefixes.

A database session resolves a stored type against its prepared application's
manifest and loads that app's local class. Import caches remain app-specific.
Outside a session, callers can select `resolution_scope(prepared_application)`;
an ambiguous unscoped resolution fails instead of selecting whichever class
registered last. Shared domains share schema identity and committed data, not
Python objects, module globals or a cross-app transaction. The owner coordinates
schema changes; participants must be deployed with compatible schema revisions.

An app-owned type outside the reader's compiled schema is foreign data. Reading
it does not quarantine it or prune references to it. A type belonging to the
reader's schema but missing from the executable is an explicit resolution error,
not an empty query result. Corrupt payloads remain a separate materialization
failure.

## Clean break

Old `_jac_app_<path-hash>` identities are rejected explicitly. They cannot be
reconstructed reliably after relocation, and stripping their prefix would merge
unrelated app-owned schemas. Rebuild all source, sealed and exported artifacts.
Existing stores require an explicit identity migration before serving; never
infer a domain from an old module suffix. Back up the store and stop writers
before changing schema ownership. The change does not mutate an existing store
at application startup.

For a known legacy name, use the existing `@archetype_alias("old.module.Type")`
(or `schema_was` rule) on the destination declaration. Alias targets now use
stable identities and resolve in the consuming application too, including when
both apps are loaded. Conflicting mappings and cycles are rejected. Aliases are
explicit migration declarations, not a rule for guessing ownership from an old
path hash. Rewrite affected rows through the destination schema before removing
the alias, including references to nested persisted values. Quarantine records
can be inspected independently; an unavailable schema is not corrupt data.
