"""What `by` calls: any value implementing `By`.

`def f(a: A) -> R by e;` gives `by_call[R](e, ...)`: the call's name, its
`sem`, its arguments encoded by their types, theirs `sem`s, and its tools,
each a `by_tool` of a function. The result's JSON schema and its decoder
are made from R with compile-time reflection, as a tool's are from its
parameters, so a result type the schema can't express is refused at compile
time, never left to the prompt's text."""

import from jaclang.comptime {
    Kind,
    apply,
    args_type,
    fields,
    get_field,
    kind,
    members,
    params,
    sendable,
    type_args,
}

import from jac {
    def __sem(f: any) -> str;
}

"""A tool a model may call: its schema, and how to call it, its arguments as
JSON's values by name, its result as JSON's."""
obj:pub ByTool {
    has name: str,
        doc: str = "",
        schema: dict[str, any] = {},
        call: Callable[[dict[str, any]], any];
}

"""One call: what the compiler knows of the function, and its arguments."""
obj:pub ByCall {
    has name: str,
        doc: str = "",
        args: dict[str, any] = {},
        arg_docs: dict[str, str] = {},
        result_schema: dict[str, any] = {},
        decode: Callable[[any], any] | None = None,
        tools: list[ByTool] = [];
}

"""A plugin couldn't produce the declared type."""
obj:pub ByError(Exception) {}

obj:pub By {
    def invoke(call: ByCall) -> any abst;
}

"""What a plugin used to answer: the requests it made and, for a model, the
tokens they took and the seconds they waited."""
obj:pub ByUsage {
    has requests: int = 0,
        input_tokens: int = 0,
        output_tokens: int = 0,
        cache_read_tokens: int = 0,
        cache_write_tokens: int = 0,
        seconds: float = 0.0,
        model: str = "";

    """This with `more` added to it."""
    def add(more: ByUsage) {
        self.requests += more.requests;
        self.input_tokens += more.input_tokens;
        self.output_tokens += more.output_tokens;
        self.cache_read_tokens += more.cache_read_tokens;
        self.cache_write_tokens += more.cache_write_tokens;
        self.seconds += more.seconds;
        if more.model != "" {
            self.model = more.model;
        }
    }
}

"""What an event of a streamed call says."""
enum:pub ByEventKind {
    TEXT = "text",
    TOOL_CALL = "tool_call",
    TOOL_RESULT = "tool_result",
    USAGE = "usage",
    DONE = "done",
}

"""One thing a plugin says as it works on a call it streams:
- TEXT: `text`, the next piece of its answer;
- TOOL_CALL: it calls tool `tool` with `args`, the call named `call_id`;
- TOOL_RESULT: what that call gave, `result`;
- USAGE: `usage`, what one request took;
- DONE: the call is answered: `text` is the whole answer."""
obj:pub ByEvent {
    has kind: ByEventKind,
        text: str = "",
        tool: str = "",
        call_id: str = "",
        args: dict[str, any] = {},
        result: str = "",
        usage: ByUsage | None = None,
        # (A typed call's result, for the plugin's own use: stdjac.llm's.)
        value: any = None;
}

"""A choice a walker asks a plugin to make (`visit <nodes> by b;`): which of
`options` it goes to. `name` says which walker asks, and where. The walker
(`asker`),
the node it is at and each option are described as JSON's values: a `type`,
what the type's `sem` says it `means`, its `fields` and their `sem`s
(`field_docs`). An option is its number (`option`), the `node` there and the
`edges` that lead to it from where the walker is."""
obj:pub ByChoice {
    has name: str,
        asker: dict[str, any] = {},
        at: dict[str, any] = {},
        options: list[dict[str, any]] = [];
}

"""A plugin that chooses a walker's way: the numbers of the options to take,
in the order to take them."""
obj:pub ByChooser {
    def choose(choice: ByChoice) -> list[int] abst;
}

"""A kind of edge a walker's way may be: `of` describes an edge of the kind,
and gives None for any other."""
obj:pub ByWay {
    has of: Callable[[any], dict[str, any] | None];
}

"""A plugin that answers as it goes: what `def f(...) -> Iterator[ByEvent] by
b;` asks of `b`. The call has no result type: its answer is text."""
obj:pub ByStreams {
    def stream(call: ByCall) -> Iterator[ByEvent] abst;
}

"""What the compiler says of a type that has no JSON schema (E0109)."""
comptime NO_SCHEMA: str = "a `by` result's type has no JSON schema: no any, bytes, tuple, walker or function value";

"""The JSON schema of type T, with each field's `sem` as its description. A
type that is not sendable has none: no value of it is decoded from JSON, and
`kind` has nothing to say of some of them (a function value)."""
def:pub schema[T] -> dict[str, any] {
    comptime if sendable(T) {
        return schema_in[T]([]);
    } else {
        comptime assert False, NO_SCHEMA;
        return {};
    }
}

"""schema of a sendable T, within the schemas of the object types `within`
(each its class) being made: a type that holds itself, or one holding it,
says so once, as an object, rather than without end."""
def schema_in[T](within: list[any]) -> dict[str, any] {
    comptime k = kind(T);
    comptime if k == Kind.INT {
        return {"type": "integer"};
    } elif k == Kind.FLOAT {
        return {"type": "number"};
    } elif k == Kind.STR {
        return {"type": "string"};
    } elif k == Kind.BOOL {
        return {"type": "boolean"};
    } elif k == Kind.NONE {
        return {"type": "null"};
    } elif k == Kind.ENUM {
        names: list[str] = [];
        meant: list[str] = [];
        comptime for m in members(T) {
            names.append(m.name);
            comptime if m.doc != "" {
                meant.append(m.name + ": " + m.doc);
            }
        }
        return described({"enum": names}, "; ".join(meant));
    } elif k == Kind.LIST or k == Kind.SET {
        comptime E = type_args(T)[0];
        return {"type": "array", "items": schema_in[E](within)};
    } elif k == Kind.DICT {
        comptime assert kind(type_args(T)[0]) == Kind.STR, "a `by` result's dict keys are str";
        comptime V = type_args(T)[1];
        return {"type": "object", "additionalProperties": schema_in[V](within)};
    } elif k == Kind.UNION {
        comptime args = type_args(T);
        comptime assert len(args) == 2
            and (
                kind(args[0]) == Kind.NONE or kind(args[1]) == Kind.NONE
            ), "a `by` result's union is of one type and None";
        options: list[any] = [];
        comptime for a in args {
            options.append(schema_in[a](within));
        }
        return {"anyOf": options};
    } elif k == Kind.OBJ or k == Kind.NODE or k == Kind.STRUCT {
        for c in within {
            if c is T {
                return {"type": "object"};
            }
        }
        return object_schema[T](within + [T]);
    } else {
        comptime assert False, NO_SCHEMA;
        return {};
    }
}

"""An object's JSON schema: its fields, those without a default required."""
def object_schema[T](within: list[any]) -> dict[str, any] {
    props: dict[str, any] = {};
    required: list[str] = [];
    comptime for f in fields(T) {
        props[f.name] = described(schema_in[f.type](within), f.doc);
        comptime if not f.has_default {
            required.append(f.name);
        }
    }
    return {"type": "object", "properties": props, "required": required};
}

"""A schema with what a `sem` says of the thing it describes, before what the
schema says of itself (an enum's members' meanings)."""
def:pub described(schema: dict[str, any], doc: str) -> dict[str, any] {
    if doc == "" {
        return schema;
    }
    out: dict[str, any] = dict(schema);
    out["description"] = doc + " (" + str(schema["description"]) + ")"
        if "description" in schema
        else doc;
    return out;
}

"""Function `f` as a tool, named `name`: described by its `sem`, its schema
its parameters', each described by its own `sem`."""
def:pub by_tool(comptime f: any, name: str) -> ByTool {
    props: dict[str, any] = {};
    required: list[str] = [];
    comptime for p in params(f) {
        props[p.name] = described(schema[p.type](), p.doc);
        comptime if not p.has_default {
            required.append(p.name);
        }
    }
    return ByTool(
        name=name,
        doc=__sem(f),
        schema={"type": "object", "properties": props, "required": required},
        call=lambda (given: dict[str, any]) -> any {
            a = decode[args_type(f)](given);
            return encode(apply(f, a));
        },
    );
}

"""Method `m` of `target`'s class as a tool, named `name`, which calls it on
`target`: described by the method's `sem`, its schema its parameters'. What
`tools=[r.read_file]` gives, `r` a parameter of the `by` function."""
def:pub by_method[T](comptime m: any, target: T, name: str) -> ByTool {
    props: dict[str, any] = {};
    required: list[str] = [];
    comptime for p in params(m) {
        props[p.name] = described(schema[p.type](), p.doc);
        comptime if not p.has_default {
            required.append(p.name);
        }
    }
    return ByTool(
        name=name,
        doc=__sem(m),
        schema={"type": "object", "properties": props, "required": required},
        call=lambda (given: dict[str, any]) -> any {
            a = decode[args_type(m)](given);
            return encode(apply(m, a, target));
        },
    );
}

"""What `def f(...) -> R by b;` returns, `name` being f's: what `b` gives for
the call, as R. f's `sem` and its parameters' are the call's docs. A plugin
decodes its result with the call's `decode`, which raises CodecError for a
value that isn't an R."""
def:pub by_call[R](
    comptime f: any, name: str, b: dyn By, args: dict[str, any], tools: list[ByTool]
) -> R {
    arg_docs = docs_of(f, args);
    comptime if sendable(R) {
        out = b.invoke(
            ByCall(
                name=name,
                doc=__sem(f),
                args=args,
                arg_docs=arg_docs,
                result_schema=schema[R](),
                decode=lambda (v: any) -> any { return decode[R](v); },
                tools=tools,
            ),
        );
        return out;
    } else {
        # Neither a schema nor a decoder: refused once, here.
        comptime assert False, NO_SCHEMA;
        raise ByError();
    }
}

"""The `sem`s of function `f`'s parameters that are among `args`: one the `by`
expression took whole (`by llm(conversation=history)`) is the plugin's, and
is not an argument."""
def docs_of(comptime f: any, args: dict[str, any]) -> dict[str, str] {
    arg_docs: dict[str, str] = {};
    comptime for p in params(f) {
        if p.doc != "" and p.name in args {
            arg_docs[p.name] = p.doc;
        }
    }
    return arg_docs;
}

"""What `def f(...) -> Iterator[ByEvent] by b;` returns, `name` being f's: the
events `b` gives as it answers the call."""
def:pub by_stream(
    comptime f: any, name: str, b: dyn ByStreams, args: dict[str, any], tools: list[ByTool]
) -> Iterator[ByEvent] {
    return b.stream(
        ByCall(name=name, doc=__sem(f), args=args, arg_docs=docs_of(f, args), tools=tools)
    );
}

"""`x`, a T, described for a chooser: its type `name`, what its `sem` says it
`means`, and its fields that have a JSON form, with their `sem`s."""
def:pub by_shown[T](x: T, name: str, means: str) -> dict[str, any] {
    held: dict[str, any] = {};
    docs: dict[str, str] = {};
    comptime for f in fields(T) {
        comptime if sendable(f.type) {
            held[f.name] = encode(get_field(x, f.name));
            if f.doc != "" {
                docs[f.name] = f.doc;
            }
        }
    }
    out: dict[str, any] = {"type": name, "fields": held};
    if means != "" {
        out["means"] = means;
    }
    if len(docs) > 0 {
        out["field_docs"] = docs;
    }
    return out;
}

"""Edge type E, named `name`, whose `sem` says it `means`, as a way."""
def:pub by_way[E](name: str, means: str) -> ByWay {
    return ByWay(
        of=lambda (e: any) -> dict[str, any] | None {
            # (An edge of another type is not one of these: taking it as
            # an E says so.)
            try {
                way: E = e;
                return by_shown(way, name, means);
            } except TypeError {
                return None;
            }
        },
    );
}

"""What `visit <options> by <chooser>;` visits: those of `options`, nodes of
type N (named `kind`, whose `sem` says it `means`), that `chooser` picks for
the walker `asker` describes, which is at node `at` (`at_shown`); in the
order it picks them. Each option is shown with the edges from `at` to it,
those of the kinds `ways` know."""
def:pub by_choose[N: Node](
    chooser: dyn ByChooser,
    name: str,
    asker: dict[str, any],
    at: Node,
    at_shown: dict[str, any],
    kind: str,
    means: str,
    options: list[N],
    ways: list[ByWay],
) -> list[N] {
    if len(options) == 0 {
        return [];
    }
    leaving = [edge at -->];
    shown: list[dict[str, any]] = [];
    for (i, n) in enumerate(options) {
        via: list[dict[str, any]] = [];
        there: Node = n;
        for e in leaving {
            if rt_edge_dst(e) is there {
                for w in ways {
                    said = w.of(e);
                    if said is not None {
                        via.append(said);
                        break;
                    }
                }
            }
        }
        shown.append({"option": i, "node": by_shown(n, kind, means), "edges": via});
    }
    picked = chooser.choose(ByChoice(name=name, asker=asker, at=at_shown, options=shown));
    taken: list[N] = [];
    for i in picked {
        if 0 <= i and i < len(options) and options[i] not in taken {
            taken.append(options[i]);
        }
    }
    return taken;
}
