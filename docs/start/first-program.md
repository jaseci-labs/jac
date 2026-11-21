---
description: Write, check, build and run a first Jac program, then one with a node, an edge and a walker, and read a diagnostic and look its code up.
---
# A first program

This page takes a program from a file to a running executable, then does the same for a small graph program, then shows what an error looks like and how to look it up. It assumes jac is installed ([Install](install.md)).

## Write it

A Jac source file ends in `.jac`. Save this as `hello.jac`:

```jac
def greet(name: str) -> str {
    return f"hello, {name}";
}

with entry {
    print(greet("jac"));
}
```

```output
hello, jac
```

- `def` declares a function. Parameters and the return value have types.
- `with entry { ... }` is the module's code: what runs when the program starts. A module with no `with entry` block runs nothing.
- Statements end with `;` and blocks are in braces. Indentation means nothing to the compiler.

## Check it

```sh
jac check hello.jac
```

`check` runs everything a build checks (syntax, names, types, ownership) and builds nothing. It prints nothing when the program is right and exits with status 0. See [check](../toolchain/check.md).

## Build it and run it

```sh
jac build hello.jac -o hello
./hello
```

```text
hello, jac
```

`build` writes one executable, the file `-o` names. It is a native program: it needs no jac, and nothing else installed, where it runs. `jac run hello.jac` builds it and runs it in one step, with the program's arguments after `--` ([build](../toolchain/build.md)).

On a terminal, a build that takes more than a moment shows one status line while it works and ends with one line:

```text
✓ Built hello in 1.94s
```

Run the same build again with nothing changed and it does nothing:

```text
✓ hello is up to date
```

When its output is not a terminal (a pipe, a file, CI), a build that succeeds prints nothing at all. The exit status says whether it worked.

A build keeps what it compiles in a cache, so the first build of anything compiles the runtime's modules too and later builds compile only what an edit changed. See [build](../toolchain/build.md) and [The build cache](../toolchain/cache.md).

## A program with a graph

Jac programs can hold their data as a graph: nodes joined by edges, and walkers that move over them. Save this as `tour.jac`:

```jac
node City {
    has name: str;
}

edge Road: City --> City {
    has km: int = 0;
}

walker Tour {
    has seen: list[str] = [],
        km: int = 0;

    can arrive with City entry {
        self.seen.append(here.name);
        for road in [edge here ->:Road:->] {
            self.km += road.km;
        }
        visit [here ->:Road:->];
    }
}

with entry {
    paris = City(name="Paris");
    lyon = City(name="Lyon");
    nice = City(name="Nice");
    paris +>:Road(km=465):+> lyon;
    lyon +>:Road(km=470):+> nice;
    tour = paris spawn Tour();
    print(tour.seen);
    print(tour.km, "km");
}
```

```output
['Paris', 'Lyon', 'Nice']
935 km
```

What each part is:

| Code | Meaning |
|---|---|
| `node City { has name: str; }` | A node type with one field. `has` declares fields |
| `edge Road: City --> City { ... }` | An edge type. An edge names the node types it joins; one that does not is error E2086 |
| `walker Tour { ... }` | A walker type: an object that travels the graph, with fields of its own |
| `can arrive with City entry { ... }` | An ability: code the walker runs each time it arrives at a `City`. `here` is the node it is at, `self` the walker |
| `paris +>:Road(km=465):+> lyon;` | Connect `paris` to `lyon` with a new `Road` edge |
| `[here ->:Road:->]` | The nodes that `Road` edges lead to from `here` |
| `[edge here ->:Road:->]` | Those `Road` edges themselves |
| `visit [...]` | Queue those nodes for the walker to go to next |
| `paris spawn Tour()` | Start a `Tour` at `paris` and run it until it has nowhere left to go. The result is the walker |

Build and run it the same way:

```sh
jac build tour.jac -o tour
./tour
```

The language pages define each of these precisely. `jac docs walker`, `jac docs visit` and `jac docs spawn` print the page that defines each word.

## Reading a diagnostic

Every error jac reports has the same shape. This program has two mistakes:

```jac
# expect: E1030 x2
node City {
    has name: str;
}

with entry {
    paris = City(name="Paris");
    paris.population = 2100000;
    print(paris.nmae);
}
```

```sh
jac check wrong.jac
```

```text
wrong.jac:8:5: error[E1030]: City has no field 'population'
 8 |     paris.population = 2100000;
   |     ^^^^^^^^^^^^^^^^

wrong.jac:9:11: error[E1030]: City has no field 'nmae'
 9 |     print(paris.nmae);
   |           ^^^^^^^^^^

2 errors
`jac docs E1030` explains an error by its code.
```

Each diagnostic is:

1. `file:line:column:` where it is. Lines and columns count from 1.
2. `error[CODE]:` its code. A code names one condition: `E1030` always means a field that does not exist.
3. The message.
4. The source line, marked with `^` from where the mistake's place starts to where it ends.

After the last one comes the count, then a line naming the command that explains the first error's code. The exit status is 1. Everything goes to stderr.

jac reports every error it finds in a phase before it stops, so one run usually shows several. Fix them all, then run `check` again: errors of a later phase (types, after syntax) show only once the earlier phase is clean.

A code that starts with `W` is still an error here: `error[W2001]`. jac uses the code the reference design has for the same condition, and where the reference design only warns, jac refuses the program. The one exception is W0060, a string that documents nothing: it is shown as `warning[W0060]` and fails nothing.

## Looking a code up

The last line of a failed check names the command that explains its first error:

```sh
jac docs E1030
```

It prints the code's entry: the message as the compiler words it, what the code means, a program that raises it, the fix, and the page the entry is on. A code is looked up whatever its case (`jac docs e1030`).

`jac docs <word>` does the same for any word jac has: a keyword (`jac docs visit`), a builtin (`jac docs print`), a command (`jac docs build`), a lint rule, a `jac.toml` key, an environment variable. `jac docs search <text>` finds the pages that mention a text, and `jac docs` alone prints the map of every page. See [docs and skills](../toolchain/docs.md) (`jac docs toolchain/docs`).

## Where to go next

- [Projects](../toolchain/projects.md) (`jac docs toolchain/projects`): more than one file, `jac.toml`, where jac puts what it makes.
- [test](../toolchain/test.md) (`jac docs toolchain/test`): `test` blocks and `jac test`.
- [fmt](../toolchain/fmt.md) (`jac docs toolchain/fmt`): the one layout Jac source is written in.
