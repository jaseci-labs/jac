---
description: How an archwire.jac groups a project's modules into layers, nested and named, so that every module is in exactly one, an edge rule at each level of the layers admits every wire that crosses there, and no two layers take from each other.
keywords: graph layers, layer, layers, layering, layer cycle
grammar: graph_layers, layer_decl
---
# Layers

A **layer** is a named group of a project's modules. Every `archwire.jac` declares its layers, in
a `graph layers` block, and the project's shape is then something the compiler holds it to: every
module is in exactly one layer, a wire between two layers needs an [edge rule](modules-wiring.md#edge-rules)
that admits it at every level of the layers it crosses, and no two layers take from each other.

Layers are also what [`jac arch`](../toolchain/arch.md) draws: each is a box, and the wires
between them are the arrows.

```ebnf
graph_layers ::= "graph" "layers" "{" (STRING layer_decl | layer_decl)* "}"

layer_decl ::= "layer" NAME "{" (STRING layer_decl | layer_decl | module_pattern ("|" module_pattern)* ";")* "}"
```

<!-- example: not checked: a graph layers block is valid only in a file named archwire.jac, beside the modules it groups -->
```jac
graph layers {
    """What the program stands on."""
    layer platform {
        """Clocks, and nothing else."""
        layer time { core.clock; }

        """The machine the program runs on."""
        layer machine { core.host | core.posix | core.shared | core.win; }
    }

    """What the user sees."""
    layer screen { app.* | main; }
}

graph import {
    """The screen is drawn from the platform."""
    edge Core: platform --> screen;
    """It reads the clock."""
    edge Clock: time --> screen;
    """It asks the machine its name."""
    edge Machine: machine --> screen;
    """A host tells the time."""
    edge Time: time --> machine;

    core.clock ++> app.view | main { now }
    core.clock ++> core.host { now }
    core.host ++> main { host_name }
}
```

## What a layer holds

A layer holds modules, or it holds other layers. It never holds both (E2212).

- **Modules**, named by pattern: a module (`core.clock`), a package and everything in it
  (`app.*`), or everything `archwire.jac` governs (`*`). Each pattern matches at least one module
  (E2098).
- **Other layers.** A layer nests to any depth. Modules that would sit beside the layers inside
  one get a layer of their own there, as `machine` is above, so every box of a picture is one kind
  of thing and every rule has a layer to name.
- A layer holds something: one with no module and no layer is E2203.
- A docstring before a layer is one line that says what it is for ([Docstrings](modules-wiring.md#docstrings)).

`layers` and `layer` are words only here: a module named `layer` is still written `layer;`.

## Every module is in exactly one layer

Each module an `archwire.jac` governs is in exactly one **innermost** layer: the one whose own
patterns match it.

- **An `archwire.jac` that declares no layer is E2213.** It is reported once, and not once for
  each module. A project that has no layering to state yet declares one layer that holds
  everything, `layer all { *; }`: none of its wires crosses a layer, so none needs a rule.
- **A module in no layer is E2201.** It is reported for every module a wire names, and for every
  module a build loads. [`jac arch`](../toolchain/arch.md) reports it for every module
  `archwire.jac` names anywhere.
- **A module two layers hold is E2202.** `core.*` in one layer and `core.clock` in another is two
  layers holding `core.clock`: the more specific pattern does not win.

## A layer's name

- **A layer's name is its own across the project** (E0077), whatever its depth: `time` above is
  named `time` in a rule, not `platform.time`.
- **It may be the name of a package or module it holds**: `layer core { core.*; }`. In a rule the
  word is the layer, since a rule of a project with layers names nothing else of the project.

## Rules between layers

**Edge rules are stated between layers and nowhere else.** The wires say which modules take from
which; a rule says which layers may.

- **A rule names layers** (E2210). `edge Clock: core.clock --> screen;` is refused: `core.clock`
  is a module, and the wire `core.clock ++> main` already says it. A rule that should hold for one
  module alone is a layer that holds that module alone, as `time` is. The one exception is the
  source of a [rule over an import from outside the project](modules-wiring.md#rules-over-imports-written-in-modules),
  which names the package.
- **A layer in a rule is that layer as one box.** `platform --> screen` says that something in
  `platform` may feed something in `screen`. It does not say what: the rules between the layers
  inside them do.
- **A scoped block states no rule** (E2210). In `graph import core { ... }` every name is a module
  of `core`, and no rule names modules.

### A rule at every level

A wire that leaves one innermost layer for another needs a rule **at every level of the layers it
crosses** (E2099). Lift each end of the wire to the layer that holds it, and then to the layer that
holds that, until the two are inside one layer or at the top: each pair of boxes on the way is a
level, and exactly one rule admits the wire at each.

`core.clock ++> main` above goes from `time`, which is inside `platform`, to `screen`:

| Level | From | To | Rule |
|---|---|---|---|
| The project's own layers | `platform` | `screen` | `Core` |
| Inside `platform` | `time` | `screen` | `Clock` |

`core.clock ++> core.host` crosses one level, inside `platform`, from `time` to `machine`: `Time`
admits it. An end that has no deeper layer stays as it is while the other descends, as `screen`
does.

- **Each level is its own rule.** `Core` does not admit `core.clock ++> main` inside `platform`,
  and `Clock` does not admit it at the top. A lower rule with no rule above it is E2099 at the
  level above; an upper rule that no wire reaches is E2205.
- **One rule admits a wire at a level** (E2208): two that both do are two names for one arrow.
- A wire between two modules of one innermost layer needs no rule. To hold them to one, give each
  a layer.

[`jac arch`](../toolchain/arch.md) draws each level as its own picture, and the rule of that
level is the name on the arrow.

## Layers do not take from each other

**A cycle between layers is E2204.** If any module of one layer takes from another layer, no
module of the second takes from the first, directly or through other layers. The layers inside one
layer are held to the same among themselves, and so are a layer's own modules and the layers it
holds.

The message gives the cycle as the wires that make it:

```text
archwire.jac:17:19: error[E2204]: layers take from each other in a cycle: low --> mid (core.clock --> core.util); mid --> low (core.util --> core.base)
```

## Layers and spaces

A layer says what part of the design a module belongs to. A [space](../apps/archwire.md) says where
it runs. They are independent, and a module has one of each.

## What is rejected

| Code | Condition |
|---|---|
| E0164 | Anything but a layer in a `graph layers` block |
| E0165 | Anything but layers and module patterns in a layer |
| E0166 | A docstring that describes nothing |
| E0077 | A layer named as another layer |
| E2098 | A layer's pattern matches no module |
| E2213 | An `archwire.jac` that declares no layer |
| E2201 | A module in no layer |
| E2202 | A module in two layers |
| E2203 | A layer that holds nothing |
| E2212 | A layer that holds layers and modules of its own |
| E2204 | Layers that take from each other |
| E2099 | A wire between two layers that no rule admits, at any level it crosses |
| E2210 | A rule that names modules |
| E2209 | A docstring of more than one line or 120 characters |
