---
name: writing-a-plugin
description: Use when writing or changing a jac plugin - a package that carries out one of the language's abstractions (store, auth, transport, llm, jobs, schedule, limits, ui, bundler) - deciding between a plugin and a library, the package's jac.toml, a class whose fields are its settings, a ui or bundler plugin's table, declaring it by path in a project, picking it with JAC_<ABSTRACTION>, and what a build refuses.
---
# Writing a plugin

## When to use this

Use it when a project needs one of the language's abstractions carried out another way: its graph
kept in another database, its callers signed in by another service, `by llm()` answered by another
model's API, its components compiled for another UI library.

- **Write a plugin** when no module should change. A plugin fills an abstraction the language
  already has, the project names it in `jac.toml`, and nothing imports it.
- **Write a library** when code should call it: a function, a class, a client of some service that
  a module imports and uses by name. A library is declared in `[packages]`,
  as a plugin is (`jac docs toolchain/packages`). A package is one or the other, never both.
- **Neither** adds an abstraction. Those are the language's and stdjac's (E2217).

Load `writing-jac` first. Using the plugins jac ships, in an app: `building-an-app`.

## Before you start

```sh
jac docs plugins            # the abstractions, binding, settings, secrets, what is refused
jac docs stdjac.server      # the interfaces Auth, Jobs, Scheduler, Limits
jac docs apps/ui-bindings   # ui and bundler plugins: their tables, a bundler's job
jac docs principles         # why a plugin is never imported
```

Find the abstraction's row first: its interface is what the plugin's class conforms to.

| Abstraction | Interface | Picked | A worked example in jac's repository |
|---|---|---|---|
| `store` | `stdjac.graph.Store` | As the program starts | `tests/plugins/jsonstore` |
| `auth` | `stdjac.server.Auth` | As the program starts | `tests/plugins/ticket_auth` |
| `transport` | `stdjac.remote.Transport` | As the program starts | `tests/plugins/line_transport` |
| `llm` | `stdjac.llm.Model` | As the program starts | `tests/plugins/chat_model` |
| `jobs` | `stdjac.server.Jobs` | As the program starts | `tests/plugins/queue_jobs` |
| `schedule` | `stdjac.server.Scheduler` | As the program starts | `tests/plugins/timer_schedule` |
| `limits` | `stdjac.server.Limits` | As the program starts | `tests/plugins/file_limits` |
| `ui` | A `[ui]` table | As a space is built | `plugins/solid` |
| `bundler` | A `[bundler]` table | As a space is built | `plugins/vite` |

The plugins jac ships are in `plugins/`, each the standard one of its abstraction.

## Steps

1. **Make the package**: a directory named for the plugin, with a `jac.toml`. The name is letters,
   digits and `_`, since the class is named through it.

```toml
# window_limits/jac.toml
[project]
name = "window_limits"
kind = "plugin"

[plugin]
fills = "limits"
interface_ver = 1
class = "window_limits.limits.WindowLimits"
```

   `class` is `<plugin>.<module>.<Class>`: here `WindowLimits` of `limits.jac` in the package's
   directory. `interface_ver` is the version of the abstraction's interface you wrote the plugin
   for, which `jac docs plugins` gives: 1 for every interface of this jac. It is required.

2. **Write the class**, inheriting the abstraction's interface and defining every method it has.

<!-- example: not checked: a plugin is a package of its own, with a jac.toml that names this class -->
```jac
import time;
import from stdjac.server { Limits }

obj WindowLimits(Limits) {
    """How many seconds a refused caller is told to wait, at most."""
    has longest_wait: int = 3600;
    has began: dict[str, float] postinit;
    has used: dict[str, int] postinit;

    def postinit {
        self.began = {};
        self.used = {};
    }

    def consume(scope: str, actor: str, limit: int, seconds: int) -> int {
        key = scope + "|" + actor;
        now = time.time();
        if key not in self.began or now - self.began[key] >= seconds {
            self.began[key] = now;
            self.used[key] = 0;
        }
        if self.used[key] >= limit {
            return min(self.longest_wait, int(seconds - (now - self.began[key])) + 1);
        }
        self.used[key] += 1;
        return 0;
    }
}
```

   - **A field is a setting.** `longest_wait` is what a project's `[limits.window_limits]` may
     give, and what `JAC_LIMITS_LONGEST_WAIT` overrides where the program runs. Give each a
     default unless a project must say it (an API's address): a field with none that is given no
     value is E1050.
   - **State of its own is a `postinit` field,** which no constructor takes and no project sets.
   - **Do nothing in `postinit` but make empty state.** The plugin is made with `jac.toml`'s
     settings, then given the environment's, and only then used. Reach a file, a service or an
     address where the interface says to (`Store.open`, `Auth.open`, `Transport.claim`), or the
     first time a method needs it.
   - **A key or a password is a `Secret`**, never a `str`:
     `has key: Secret = Secret(variable="CHAT_API_KEY");` with
     `import from stdjac.bound { Secret }`. It is read with `self.key.get()` when it is needed,
     is not in the program, and cannot be written in `jac.toml` (E1053).
   - **Import stdjac and libraries, never a plugin** (E2218). A Jac library that is not jac's
     own goes in the plugin's own `[packages]`. `stdjac.plan`'s `data_dir()` is where a program
     keeps its files, and `stdjac.sqlfile`'s `open_db` opens a SQLite file at a layout.
   - **It is compiled for every host its abstraction runs on**, a `cpython` space among them.
     There a class imported from a Python module is no type: do not annotate with one.

3. **Declare it in a project by its path, and list it.** A table under the abstraction lists a
   plugin, which compiles it into the program. `plugin` names the one a program starts with when
   nothing says otherwise.

```toml
# shop/jac.toml
[project]
name = "shop"

[packages]
window_limits = { path = "../window_limits" }

[limits.window_limits]
longest_wait = 30
```

   Here the standard plugin is still the one named, and `window_limits` is built in beside it.
   `[limits]` `plugin = "window_limits"` makes it the one a program starts with.

4. **Run one built program under each plugin.** The abstraction's own programs are the test: what
   a program prints under the standard plugin, it prints under yours, wherever the abstraction
   says the two agree.

<!-- example: not checked: needs the project above, with the plugin beside it -->
```jac
import from stdjac.server { consume_limit }

with entry {
    print([consume_limit("try", "amy", 2, 60) for i in range(3)]);
}
```

```sh
jac build main.jac -o main
./main                                                   # [0, 0, 60]: memory_limits
JAC_LIMITS=window_limits ./main                          # [0, 0, 30]: yours, as jac.toml set it
JAC_LIMITS=window_limits JAC_LIMITS_LONGEST_WAIT=5 ./main   # [0, 0, 5]
```

   In an app, the variable is given to the app's program the same way:
   `JAC_STORE=jsonstore dist/api-linux-x86_64`. Keep such a project beside the plugin as its
   test: jac's own are `tests/driver/apps.jac`'s, which run one service under both plugins of
   every abstraction and compare what a client prints.

5. **For `ui` or `bundler`, write a table and no class.** Nothing of such a plugin runs with the
   program: it says what the compiler and the build make of a JavaScript space.

```toml
# tools/bundle/jac.toml
[project]
name = "bundle"
kind = "plugin"

[plugin]
fills = "bundler"
interface_ver = 1

[bundler]
build = "bundle.mjs"
settings = ["minify"]
```

```toml
# the project's jac.toml
[packages]
bundle = { path = "tools/bundle" }

[spaces.site.bundler]
plugin = "bundle"

[spaces.site.bundler.bundle]
minify = true
```

   - A `bundler`'s `build` script is run as `jac node <script> <job>`, the job a JSON file
     with where the space's compiled modules are, where to write, and the `settings` given.
   - A `ui` plugin's `[ui]` table names the library's functions for state, derived values and
     effects, its hosts and the npm packages it owns. Copy `plugins/solid/jac.toml` or
     `plugins/preact/jac.toml` and change the names.
   - A space is built with one plugin of each: there is no `JAC_UI`, and its settings are
     `jac.toml`'s alone. Test it by building one space under each plugin
     (`jac emit-js <space> -o js`, then `jac build <app>`).

## What a correct result looks like

- `jac build` prints no error, and the program runs with no variable set as it did before the
  plugin was listed.
- With `JAC_<ABSTRACTION>=<plugin>` the same executable uses the plugin, and prints what the
  abstraction's programs print under the standard one.
- `JAC_<ABSTRACTION>` naming a plugin `jac.toml` does not list ends the program with status 1 and
  the names it does list:
  ``JAC_LIMITS=nope: this program was not built with a plugin 'nope' for `limits`. jac.toml lists: memory_limits, window_limits``.
- No module of the project imports the plugin, and none changed when it was listed.

## Mistakes to expect

| Symptom | Means | Fix |
|---|---|---|
| E2214 `no plugin 'x'` | `jac.toml` names a plugin `[packages]` does not declare | Declare it: `x = { path = "..." }` |
| E2230 `the plugin 'x' was written for version 1 of ...` | The abstraction's interface has another version in this jac | Write the plugin for this jac's interface, and say its version in `interface_ver` |
| E2227 `the plugin 'x' is declared and never used` | `[packages]` declares it and nothing binds or lists it | List it, `[<abstraction>.x]`, or take the line out |
| E2215 `plugin 'x' fills ...` | It is listed under another abstraction than its `fills` | List it under the one it fills |
| E2216 `plugin 'x' ...` | No `jac.toml` at the path; `kind` is not `"plugin"`; `name` is not the declared one; no `fills`, no `class`, or for `ui` and `bundler` no table | Fix the path or the plugin's `jac.toml` |
| E1281, E1282 at the plugin's class | The class lacks a method of the interface, or one has another signature | Define each method as the interface declares it |
| E1052 at a line of `jac.toml` | A key under the plugin's table is no field of its class (a `postinit` field is none either) | Make it a field, or take the key out |
| E1053 at a line of `jac.toml` | A value of another type than the field's, or a `Secret` written down | Fix the value; give a secret by its variable where the program runs |
| E1050 at the plugin's table | A field with no default is given no value | Give it in `jac.toml`, or give the field a default |
| E2218 in a module | A module imports the plugin | Delete the import: use the abstraction (`root`, `by llm()`, `consume_limit`) |
| E2217 | The plugin's `jac.toml` has `[abstractions]` | Remove it: a plugin fills an abstraction and adds none |
| E5158 in a space's `ui` or `bundler` table | A second plugin's table there, or a setting the plugin's `settings` does not list | One plugin for a space; list the setting in the plugin's `jac.toml` |
| E2018 `unknown type` in the plugin, only in an app with a `cpython` space | A class of a Python module used as a type there | Leave such a value unannotated |
| The program ends with status 1 naming a variable | `JAC_<ABSTRACTION>` names an unlisted plugin, or `JAC_<ABSTRACTION>_<FIELD>` holds a value that is not of the field's type | List the plugin; a `str` is taken as written, any other type as JSON |

## Where to look things up

- `jac docs plugins`: binding, picking where a program runs, settings, secrets, the standard
  plugins, what is refused.
- `jac docs apps/ui-bindings`: a `[ui]` table's keys, a bundler's job and its `serve` script.
- `jac docs stdjac.server`, `jac docs stdjac`: the interfaces, and `stdjac.bound`,
  `stdjac.plan`, `stdjac.sqlfile`.
- `jac docs toolchain/packages`: libraries, and a package declared by a repository
  (`{ git = "...", rev = "..." }`), which `jac install` fetches.
- `jac docs E2216`: any code above.
