# Access Modifiers

Jac has three access modifiers -- `:pub`, `:protect`, and `:priv` -- written as a tag on a declaration (`def:pub`, `has:priv`, `walker:protect`, `glob:protect`, ...). They share one intuition: `:pub` is the most exposed, `:priv` the most contained, and `:protect` sits in the middle.

The essential rule is that **the same three keywords mean different things depending on where the symbol is declared**, and one *additional*, orthogonal meaning when the symbol is served as an HTTP endpoint. There are three contexts:

| Context | Applies to | What the modifier controls |
|---|---|---|
| [Member encapsulation](#member-encapsulation) | `has` / `def` declared **inside an archetype** | who may reference the member in source |
| [Module and project visibility](#module-and-project-visibility) | top-level `glob` / `obj` / `def` / `enum` / `walker` | which modules may reference the symbol in source |
| [Service auth](#service-auth) | top-level `def` / `walker` in an app with a server (`jac run`) | whether the symbol is served, and whether an HTTP caller must authenticate |

The first two are **compile-time reference rules** enforced by `AccessCheckPass`. The third is decided at compile time from the same tag and enforced by the server. A single tag on a top-level `walker` is read by *both* the visibility rule and the endpoint rule; they ask different questions but agree on direction: `:pub` is the most exposed, plain and `:priv` the most contained.

---

## Member encapsulation

For a `has` field or `def` ability declared **inside an archetype** (`obj`, `node`, `edge`, `walker`, `class`), the modifier is classic OOP encapsulation:

| tag | accessible from |
|---|---|
| `:pub` | anywhere |
| `:protect` | the declaring archetype **and its subclasses** |
| `:priv` | the declaring archetype **only** |

```jac
obj PetRecord {
    has:pub  name: str;
    has:protect medical_history: list[str] = [];   # this class + subclasses
    has:priv owner_contact: str = "";               # this class only

    def:protect add_record(r: str) { self.medical_history.append(r); }
}

obj VetRecord(PetRecord) {
    def:pub note(n: str) {
        self.add_record(n);          # OK: protected, accessible from a subclass
        # self.owner_contact;        # ERROR: private to PetRecord
    }
}
```

---

## Module and project visibility

For a **top-level** symbol (`glob`, `obj`, `def`, `enum`, `walker` at module scope, not inside a class), the modifier controls cross-module reference legality. A *project* is the directory tree rooted at its `jac.toml`.

| tag | visible from | meaning |
|---|---|---|
| `:pub` | any module, **including a consuming project** | exported library endpoint -- need not even be referenced inside its own project |
| `:protect` | any module **within the same project** (same `jac.toml` root) | project-internal |
| `:priv` | the **declaring module only** | module-internal |

```jac
glob:pub     API_VERSION = "1.0";   # other projects may import this
glob:protect retry_budget = 3;      # any module in this project; not exported
glob:priv    _cache = {};           # this module only
```

A reference from the same module is always allowed regardless of tag.

> **Note:** these are *visibility* rules -- they govern whether one symbol may legally reference another in source. The same tag, read on the endpoint axis, also decides which top-level walkers/functions are served; that is [service auth](#service-auth) below.

---

## Service auth

For a top-level `def` or `walker` in an app that has a server, the modifier also decides **whether the symbol is an endpoint at all**, and if so whether an HTTP caller must authenticate. Exposure comes from the declaration alone; nothing is inferred from callers, entry imports, `_` prefixes, or `[placement.pins]`. The compiler records one verdict per declaration and the type checker, the client bundler, the server, and cross-app imports all read that same verdict.

| tag on a top-level `def` / `walker` | served? | auth required? | notes |
|---|---|---|---|
| `:pub` | **yes** | **no** | open endpoint. Anonymous callers run on the shared guest graph (`root.shared`); a caller presenting a valid token runs on their own root. |
| `:protect` | **yes** | **yes** | JWT required; runs on the caller's own isolated root. |
| `:priv` | **no** | -- | private: not an endpoint, not importable by client code (`E5082`), not bridgeable from another app (`E5106`). |
| (unmarked) | **no** | -- | identical to `:priv` -- private by default. |

> **Plain is private.** A `def` or `walker` with no tag is an ordinary in-process symbol. To serve it, say so on the declaration: `def:protect` for an authenticated endpoint, `def:pub` for an anonymous one. Earlier releases served every plain walker and every entry-imported plain `def` with auth; `jac fix access` rewrites those to `:protect` (see [Breaking changes](../../community/breaking-changes.md)).

See the [Scale Reference](../plugins/jac-scale.md) for the full serve/auth model, including per-user data isolation and permission grants (which are a *third*, separate concern from endpoint auth).

---

## Enforcement and rollout

The compile-time visibility rules (member and module/project) are reported by `AccessCheckPass` in the type-check schedule. They are **warnings by default**, promoted to **hard errors** with:

```toml
# jac.toml
[check]
enforce_access = true
```

Diagnostics, each individually suppressible via `[check] suppress` or `# jac:ignore[...]`:

| code | violation |
|---|---|
| `E/W2034` | use of a `:priv` member outside its declaring archetype |
| `E/W2035` | use of a `:protect` member outside the class hierarchy |
| `E/W2037` | cross-module use of a `:priv` (module-private) top-level symbol |
| `E/W2038` | cross-project use of a `:protect` (project-protected) top-level symbol |

Symbols with no Jac source (Python/builtin/synthetic) are always treated as public. The service-auth behavior is unaffected by `enforce_access` -- auth is applied at serve time regardless.
