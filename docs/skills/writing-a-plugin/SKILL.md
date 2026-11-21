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
jac docs plugins            # the abstractions, their contracts, binding, settings, what is refused
jac docs auth.contract      # the interfaces Auth, Jobs, Scheduler, Limits, and their hosts
jac docs apps/ui-bindings   # ui and bundler plugins: their tables, a bundler's job
jac docs principles         # why a plugin is never imported
```

Find the abstraction's row first: its interface is what the plugin's class conforms to, and its
contract the one module of jac's the plugin imports it from.

| Abstraction | Interface | Picked | The plugin jac ships |
|---|---|---|---|
| `store` | `store.contract.Store` | As the program starts | `abstractions/store/sqlite` |
| `auth` | `auth.contract.Auth` | As the program starts | `abstractions/auth/accounts` |
| `transport` | `transport.contract.Transport` | As the program starts | `abstractions/transport/http` |
| `llm` | `llm.contract.Model` | As the program starts | `abstractions/llm/anthropic` |
| `jobs` | `jobs.contract.Jobs` | As the program starts | `abstractions/jobs/process_jobs` |
| `schedule` | `schedule.contract.Scheduler` | As the program starts | `abstractions/schedule/loop_schedule` |
| `limits` | `limits.contract.Limits` | As the program starts | `abstractions/limits/memory_limits` |
| `ui` | A `[ui]` table | As a space is built | `abstractions/ui/solid` |
| `bundler` | A `[bundler]` table | As a space is built | `abstractions/bundler/vite` |

Each abstraction is a directory of jac's `abstractions/`, beside `rt/` in a release: its
`jac.toml` declares it, its `contract.jac` is the contract, and the plugins jac ships for it are
the directories beside those, each a worked example.

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
import from common.contract { Host }
import from limits.contract { Limits }

obj WindowLimits(Limits) {
    """How many seconds a refused caller is told to wait, at most."""
    has longest_wait: int = 3600;
    has began: dict[str, float] postinit;
    has used: dict[str, int] postinit;

    def postinit {
        self.began = {};
        self.used = {};
    }

    """Nothing to open: it keeps its counts in memory."""
    def open(host: dyn Host) {}

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
     settings, then given the environment's, and only then opened: `open(host)` is the first
     thing asked of it. Reach a file or a service there, an address where the interface says to
     (`Transport.claim`), or the first time a method needs it.
   - **Ask the host for what is the program's.** `open` is given the program as a `Host`
     (`common.contract`): `host.data_dir()` is where a program keeps its files. `Auth.open` and
     `Jobs.open` are given a host of their own, which has more (`AuthHost`, `JobsHost`). Keep
     what you asked, or the host itself, in a `postinit` field.
   - **A key or a password is a `Secret`**, never a `str`:
     `has key: Secret = Secret(variable="CHAT_API_KEY");` with
     `import from common.contract { Secret }`. It names a variable, and the host gives what the
     variable holds: `host.secret(self.key)`, `""` where it is not set. It is not in the program,
     and cannot be written in `jac.toml` (E1053).
   - **Import the abstraction's contract, `common.contract`, your libraries and the standard
     library**: nothing of stdjac, no other abstraction's contract (E2232), and never a plugin
     (E2218). A Jac library goes in the plugin's own `[packages]`: jac's `sqlfile`, whose
     `open_db` opens a SQLite file at a layout, is one, in `libraries/sqlfile` of its tree.
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
import from stdjac { consume_limit }

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
     effects, its hosts and the npm packages it owns. Copy `abstractions/ui/solid/jac.toml` or
     `abstractions/ui/preact/jac.toml` and change the names.
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
| E2217 | The plugin's `jac.toml` declares an abstraction (`kind = "abstraction"`, or an `[abstraction]` table) | Remove it: a plugin fills an abstraction and adds none |
| E2232 in the plugin, or in a library it declares | An import of a stdjac module, or of another abstraction's contract | Take it from the plugin's own contract or `common.contract`, or ask the host `open` was given |
| E5158 in a space's `ui` or `bundler` table | A second plugin's table there, or a setting the plugin's `settings` does not list | One plugin for a space; list the setting in the plugin's `jac.toml` |
| E2018 `unknown type` in the plugin, only in an app with a `cpython` space | A class of a Python module used as a type there | Leave such a value unannotated |
| The program ends with status 1 naming a variable | `JAC_<ABSTRACTION>` names an unlisted plugin, or `JAC_<ABSTRACTION>_<FIELD>` holds a value that is not of the field's type | List the plugin; a `str` is taken as written, any other type as JSON |

## Where to look things up

- `jac docs plugins`: binding, picking where a program runs, settings, secrets, the standard
  plugins, what is refused.
- `jac docs apps/ui-bindings`: a `[ui]` table's keys, a bundler's job and its `serve` script.
- `jac docs auth.contract`, `jac docs stdjac`: the interfaces and their hosts, and every
  contract with what it holds.
- `jac docs toolchain/packages`: libraries, and a package declared by a repository
  (`{ git = "...", rev = "..." }`), which `jac install` fetches.
- `jac docs E2216`: any code above.
