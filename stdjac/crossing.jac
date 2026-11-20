"""Crossings from a JS host: what a call over one lowers to in a
browser, hermes or node space (Checker.crossing_call), as stdjac.remote's
functions are what it lowers to in a native or cpython one.

A call's arguments and its result cross by their types, through stdjac's
codec, as on every host: a call's arguments travel by name, and what doesn't
decode as the callee's result type is the call failing (RemoteDecodeError).
What carries them is the JS runtime's transport (core.js's `post`): fetch, to
the app that serves the page or to the URL its app gives the space, or the
port of a space the process runs itself. Every call over a crossing is
awaited there."""

import from "@jac/runtime/core" { post, post_stream, decode_failed }

"""The result of a call over a crossing, as R."""
def take[R](space: str, endpoint: str, data: any) -> R {
    try {
        return decode[R](data);
    } except CodecError as e {
        decode_failed(space, endpoint, str(e));
        raise e;
    }
}

"""Call function `module`.`name` of space `space` with `args`, its arguments
by name as JSON's values: its result, as R."""
async def:pub call_async_def[R](space: str, module: str, name: str, args: dict[str, any]) -> R {
    data: any = await post(space, name, f"/__jac/call/{space}/{module}/{name}", {"args": args});
    return take[R](space, module + "." + name, data);
}

"""call_async_def for a function that gives nothing."""
async def:pub call_async_proc(space: str, module: str, name: str, args: dict[str, any]) {
    await post(space, name, f"/__jac/call/{space}/{module}/{name}", {"args": args});
}

"""Call stream function `module`.`name` of `space` with `args`: its items,
each a T, as the function makes them, read with `async for`. The call is made
when the first item is asked for."""
async def:pub call_async_stream[T](
    space: str, module: str, name: str, args: dict[str, any]
) -> AsyncIterator[T] {
    events: any = post_stream(space, name, f"/__jac/call/{space}/{module}/{name}", {"args": args});
    async for data in events {
        yield take[T](space, module + "." + name, data);
    }
}

"""Spawn walker `module`.`name` of `space` at its own root, with `args`, the
fields given, by name, as JSON's values: the walker as the walk left it,
copied back, its reports with it."""
async def:pub spawn_walker[W](space: str, module: str, name: str, args: dict[str, any]) -> W {
    endpoint = module + "." + name;
    data: any = await post(space, name, f"/__jac/spawn/{space}/{module}/{name}", {"fields": args});
    if not isinstance(data, dict) {
        decode_failed(space, endpoint, "a spawn's reply is no walker");
    }
    got: dict[str, any] = data;
    w = take[W](space, endpoint, got.get("fields", None));
    if declares_reports[W]() {
        return w;
    }
    reports: any = got.get("reports", []);
    if not isinstance(reports, list) {
        decode_failed(space, endpoint, "a spawn's reports are no list");
    }
    items: list[any] = reports;
    for r in items {
        w.reports.append(r);
    }
    return w;
}
