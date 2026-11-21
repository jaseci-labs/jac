---
description: The access tags :pub, :protect and :priv on archetypes, fields, methods, functions, globals, enums and type aliases, and what each one means today.
keywords: access tag, access tags, pub, priv, protect, :pub, :priv, :protect, visibility, public, private
grammar: access_tag
---
# Access tags

An access tag is `:pub`, `:protect` or `:priv` written directly after a
declaration's keyword. It says who the declaration is for. Its main effect
today is on a project's spaces: a tagged function or walker of a space is an
endpoint that code outside the space may call.

## Syntax

```ebnf
access_tag ::= (":" ("protect" | "pub" | "priv"))?
```

The tag follows the keyword and comes before the name. `jac fmt` writes
it against the keyword (`obj:pub`). It is optional everywhere, and a
declaration without one is untagged.

| Declaration | With a tag |
|---|---|
| Archetype | `obj:pub Point {`, `node:priv Cache {`, `walker:protect my_notes {`, `struct:pub P {` |
| Enum | `enum:pub Level {` |
| Function or method | `def:pub greet(name: str) -> str {`, `static def:priv make -> T {` |
| Ability | `can:priv log with Room entry {` |
| Field | `has:priv token: str;`, `static has:pub count: int = 0;` |
| Global | `glob:pub VERSION: str = "1";` |
| Compile-time global | `comptime:pub WIDTH: int = 8;` |
| Type alias | `type:pub Id = int;` |

One tag covers every name its statement declares: `has:priv a: int, b: int;`
tags both fields.

```jac
obj:pub Vault {
    has:priv coins: int = 0;
    has:pub label: str = "vault";

    def:pub deposit(n: int) -> int {
        self.coins += self.checked(n);
        return self.coins;
    }

    def:priv checked(n: int) -> int {
        if n < 0 {
            raise ValueError("a deposit is not negative");
        }
        return n;
    }
}

glob:priv opened: int = 0;

def:pub open_vault(label: str) -> Vault {
    opened += 1;
    return Vault(label=label);
}

with entry {
    v = open_vault("main");
    print(v.deposit(5), v.deposit(2), v.label, opened);
}
```

```output
5 7 main 1
```

## What each tag means

| Tag | Meaning |
|---|---|
| `:pub` | For anyone: other modules, other spaces, callers outside the program |
| `:protect` | For a narrower audience: on an endpoint, a signed-in caller |
| `:priv` | For the declaring module or archetype alone |
| none | For the program's own code |

What the toolchain does with a tag depends on where the declaration is.

### A function or walker of a space

In a project whose `archwire.jac` declares spaces, a module-level function
or walker of a space is an endpoint when it is tagged. An endpoint is what
other spaces, pages and outside clients may call.

| Declaration in a space | Who may call it across spaces |
|---|---|
| `def:pub` or `walker:pub` | Anyone |
| `def:protect` or `walker:protect` | A signed-in caller |
| Untagged, and wired into a module of another space | The deployment's own apps only |
| Untagged otherwise, or `:priv` | No one: it is not an endpoint |

Two errors keep the tags honest:

- **E1210**: code of a browser or other JavaScript space calls a function
  or spawns a walker of another space that carries no `:pub` or `:protect`
  tag. Such a call comes from outside the deployment, so the declaration
  must say who may make it.
- **E1211**: a function or walker is tagged `:pub` or `:protect` in a
  module that no space holds, in a project that has spaces. The tag would
  promise an endpoint that is never served.

A `node` space serves `:pub` functions; `:protect` and walker endpoints
there are refused for now (E5090).

Spaces are declared in the project's [archwire](../apps/archwire.md)
(`jac docs spaces`); endpoints and who may call them are described in
[Crossings](../apps/crossings.md) (`jac docs endpoint`).

### A library's functions and globals

`jac build --lib` makes a shared library with a C interface. It exports
the main module's `:pub` functions and `:pub` globals under their own
names. See [build](../toolchain/build.md) (`jac docs build`).

### Inside one program

Within a program, tags record intent. `jac check` does not report a use
that crosses one: reading a `:priv` field from another module compiles.
Write code as though the tags were checked, so that it keeps compiling when
they are:

- reach a `:priv` member only from the archetype that declares it;
- reach a `:priv` function, global or archetype only from its own module;
- treat `:protect` members as for the archetype and its subclasses.

## What is rejected

| Code | When |
|---|---|
| E1210 | A JavaScript space calls an untagged function or walker of another space |
| E1211 | `:pub` or `:protect` on a function or walker of a module no space holds |
| E5090 | `:protect`, or a walker endpoint, in a `node` space |
| E0003 | A tag that is not one of the three words: `obj:public` |
| E0013 | A tag written after the name: `obj Point :pub {` |

```jac
# expect: E0003
obj:public Point {
    has x: int = 0;
}
```

## Differences from Python and from the reference design

- **In Python a leading underscore marks a private name by convention;
  here the tag is part of the declaration**, and an underscore has no
  meaning to the compiler.
- **In Python every module-level name can be imported from outside; the
  same is true here**, tagged or not.
- **In the reference design reading a `:priv` member from outside its archetype is a warning
  (W2034); jac reports nothing.**

## See also

- [Archetypes](archetypes.md), [Fields](fields.md), [Methods](methods.md): the declarations a tag goes on.
- [Crossings](../apps/crossings.md): endpoints and who may call them.
