"""What starts a program of an app: the same module for every app, which
the build makes the program's main when its spaces have no `entry`, and
starts ahead of the entry module when they have one. What differs between
apps is data, the program's plan (stdjac.plan), which this reads, and the
plugins the project bound, which it asks for.

Started, it runs a job when this process was started for one; with no entry,
it takes its address, with the project's transport, before anything else.
It starts the spaces the program runs in its own process, and, with no
entry, opens the graph and the project's auth and listens: for the spaces'
endpoints (which their modules handed over as they started), the pages it
serves, the requests a page makes of the spaces it doesn't run, and the
functions served at paths of their own; and it has the project's scheduler
run the scheduled functions. A space another program of the app runs in its
process (a cpython space in embedded CPython) opens its own graph, and is
served through that program: `in_process` is its port, `space_scheduled` its
scheduled functions."""

import datetime;
import json;
import os;
import sys;
import threading;

"""Whether the app's user asked for another arrangement of it: the loop
starts the program again when it next turns (`start`'s window tick)."""
glob _relaunch: list[bool] = [];

"""What a page asks of the app that serves it (`@jac/runtime`'s
jacArrangement, and what changes it): `/__jac/app/arrangement` is which
arrangement of the app this run is and which it may be; a POST of
`{"name": ...}` chooses one, and the app starts again as it."""
def app_route(r: Request) -> Response {
    p = plan();
    if r.path.removeprefix("/__jac/app/") != "arrangement" {
        return json_fail(404, "failed", "no such endpoint");
    }
    if r.method == "POST" {
        got: any = None;
        try {
            got = json.loads(r.body.decode("utf-8")) if len(r.body) > 0 else {};
        } except ValueError {
            got = None;
        }
        if not isinstance(got, dict) {
            return json_fail(400, "rejected", "the request is not a JSON object");
        }
        fields: dict[str, any] = got;
        try {
            keep_arrangement(str(fields.get("name", "")).strip());
        } except ValueError as e {
            return json_fail(400, "rejected", str(e));
        }
        if p.window is not None {
            _relaunch.append(True);
        }
    }
    return json_ok({"names": p.arrangements, "current": p.arrangement, "chosen": p.chosen});
}

"""`path` as a person reads it: from the current directory, when it is in or
under it."""
def shown_path(path: str) -> str {
    rel = os.path.relpath(path);
    return path if rel.startswith(os.pardir) else rel;
}

"""The environment variable that asks an app to start with no data: what
`jac run <app> --fresh` sets."""
glob FRESH: str = "JAC_FRESH";

"""The environment variables `jac dev <app>` sets for the program it
starts, when the app's page is served by its bundler's dev server instead of
the program: where the program listens (DEV_LISTEN, in place of the app's
own address, which the dev server has), the page space that server serves
(DEV_SERVED), of which the program answers nothing, so that the dev server,
which asks the program first, serves it; and the page a window opens
(stdjac.desktop's DEV_PAGE)."""
glob DEV_LISTEN: str = "JAC_DEV_LISTEN",
     DEV_SERVED: str = "JAC_DEV_SERVED";

"""What keeps the program from starting that its user acts on, said in `why`,
in words: the address it is to listen at taken, data it can't read. Its
start raises it; the program says it on stderr, not as a traceback, and ends
with status 1."""
obj CannotStart(Exception) {
    has why: str;
}

"""Where a serving program listens unless it is told otherwise
(JAC_<APP>_LISTEN)."""
glob LISTEN_AT: str = "127.0.0.1:8000";

"""Take the address the program listens at, with the project's transport:
where `jac dev` says (DEV_LISTEN), else JAC_<APP>_LISTEN, else LISTEN_AT;
a `window`'s server on this machine, at a port the system picks unless
`jac dev` gives one. Where it can't, it can't start (CannotStart): the
address, why, and what has it listen elsewhere."""
def claim_address(window: bool) -> Claim {
    p = plan();
    told = env_name(p.app, "LISTEN");
    address: str = os.environ.get(DEV_LISTEN, "");
    elsewhere = "";
    if address != "" and os.environ.get(DEV_SERVED, "") != "" {
        elsewhere = "`jac dev` chose that address, behind its page's dev server: start it again for another.";
    } elif address != "" {
        elsewhere = f"To listen elsewhere, run `jac dev {p.app}` with another --listen.";
    } elif not window {
        # (Set and empty is unset, as JAC_<APP>_DATA is.)
        address = os.environ.get(told, "");
        if address == "" {
            address = LISTEN_AT;
        }
        elsewhere = f"To listen elsewhere, start it with {told}=<host>:<port>.";
    }
    if window {
        # A window's server is its own, on this machine, at a port the system
        # picks unless `jac dev` said where the page's dev server will
        # look for it. (Nothing chooses a window's otherwise.)
        address = "127.0.0.1:" + (address.rpartition(":")[2] if address != "" else "0");
    }
    try {
        return transport().claim(address);
    } except CannotListen as e {
        said = f"{p.app} can't listen on {address}: {e.reason}.";
        raise CannotStart(why=said if elsewhere == "" else f"{said} {elsewhere}");
    }
}

"""Open what the program keeps: its auth's data, when it has callers to know
(`callers`), and its graph, each where the project's plugin for it keeps it.
Data it can't start with is said, all of it at once and in words
(CannotStart): an old layout, a newer one, nodes of a type the program no
longer has."""
def open_data(callers: bool) {
    wrong: list[DataError] = [];
    if callers {
        try {
            open_auth();
        } except DataError as e {
            wrong.append(e);
        }
    }
    store: dyn Store = bound("store");
    try {
        graph_open(store, StoreCodec());
    } except DataError as e {
        if e.path == "" {
            e.path = store.kept_as();
        }
        wrong.append(e);
    }
    p = plan();
    # What was brought up to this stdjac's layouts on the way, and where the
    # files as they were are.
    for done in upgrades_made() {
        sys.stderr.write(f"{p.app}: {done}\n");
    }
    if len(wrong) == 0 {
        return;
    }
    d = data_dir();
    out = f"{p.app} can't start with the data it kept in {shown_path(d)}:\n";
    width = max([len(os.path.basename(e.path)) for e in wrong]);
    for e in wrong {
        name = os.path.basename(e.path);
        out += f"  {name}{' ' * (width - len(name))}  {e.problem}\n";
    }
    if os.environ.get(env_name(p.app, "DATA"), "") != "" {
        out += "To start empty, move that directory aside.";
    } else {
        out += f"To set that data aside and start empty, run `jac run {p.app} --fresh` in the project, or start the program with {FRESH}=1.";
    }
    raise CannotStart(why=out);
}

"""Set the app's data in `d` aside, when it was asked to start with none
(FRESH): the directory moves to one beside it named for the moment, where it
is kept. Only the data a project keeps for itself: an app told where its data
is (JAC_<APP>_DATA) keeps what someone chose to keep there, and says so."""
def set_aside(d: str) {
    if os.environ.get(FRESH, "") in ["", "0"] {
        return;
    }
    # Asked of this program alone: not of the copies it starts for its jobs.
    del os.environ[FRESH];
    p = plan();
    told = env_name(p.app, "DATA");
    if os.environ.get(told, "") != "" {
        raise CannotStart(
            why=f"{p.app} keeps its data where {told} says, in {shown_path(d)}: only a project's own data is set aside for a fresh start. Move that directory yourself.",
        );
    }
    if not os.path.isdir(d) or len(os.listdir(d)) == 0 {
        return;
    }
    stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S");
    aside = f"{d}.{stamp}";
    k = 1;
    while os.path.exists(aside) {
        k += 1;
        aside = f"{d}.{stamp}-{k}";
    }
    os.rename(d, aside);
    sys.stderr.write(
        f"{p.app}: its data is set aside in {shown_path(aside)}, and it starts with none\n"
    );
}

"""A request made in this process (the program's own code's when `trusted`),
answered as one over HTTP is: what a space run in the process is reached
through, each way."""
def:pub in_process(path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
    if path.startswith("/__jac/stream/") {
        return pull_stream(path[len("/__jac/stream/"):len(path)]);
    }
    reply = dispatch(Request(method="POST", path=path, body=body), caller, trusted);
    events = reply.events;
    if events is not None {
        # A stream: opened for the caller to pull through this port.
        return open_stream(events);
    }
    return (reply.status, reply.body);
}

"""A carried space's scheduled functions, which the program carrying it runs."""
def:pub space_scheduled -> list[Scheduled] {
    return scheduled();
}

"""A request from outside: its caller is who the project's auth says."""
def handle(r: Request) -> Response {
    return dispatch(r, auth_caller(r.headers), deployment_signed(r));
}

def reply_of(got: tuple[int, bytes]) -> Response {
    return Response(status=got[0], body=got[1]);
}

"""reply_of a reply that may be a stream: its events, where it has them."""
def stream_of(got: tuple[int, bytes, Iterator[bytes] | None]) -> Response {
    return Response(status=got[0], body=got[1], events=got[2]);
}

"""The reply to a call made past its function's limit, `seconds` before it may
be made again: None for one within it."""
def too_often(seconds: int) -> Response | None {
    if seconds <= 0 {
        return None;
    }
    failed = json_fail(429, "rejected", f"called too often: try again in {seconds} seconds");
    failed.headers = {"Retry-After": str(seconds)};
    return failed;
}

"""What answers `r` for `caller`, `trusted` when the program's own code or
another app of the deployment (signed with its key) made it."""
def dispatch(r: Request, caller: str, trusted: bool) -> Response {
    p = plan();
    if r.path.startswith("/__jac/app/") {
        return app_route(r);
    }
    call = r.path.startswith("/__jac/call/") or r.path.startswith("/__jac/spawn/");
    space = r.path.split("/")[3] if call and r.path.count("/") > 3 else "";
    if r.method == "POST" and call and carried(space) {
        # A space the program runs in its own process: carried to it.
        return stream_of(carry_stream(space, r.path, r.body, caller, trusted));
    }
    if p.accounts != "" and r.path.startswith("/__jac/auth") {
        # A window's sign-in, for an app whose accounts another app keeps.
        return stream_of(
            forward_remote(
                remote_url(p.accounts), r.path, r.body, r.headers.get("authorization", ""), r.method
            ),
        );
    }
    if r.method == "POST" and r.path in p.forwarded {
        # What a page this app serves calls in a space it doesn't run: sent on
        # as its caller's request, to the app that runs it.
        return stream_of(
            forward_remote(
                remote_url(p.forwarded[r.path]),
                r.path,
                r.body,
                r.headers.get("authorization", ""),
                r.method,
            ),
        );
    }
    if r.path.startswith("/__jac/auth") {
        return auth_route(r);
    }
    if r.method == "POST" and call and space not in p.spaces {
        # A space the program holds and this arrangement of it doesn't run.
        return json_fail(404, "failed", "no such endpoint");
    }
    if r.method == "POST" and r.path.startswith("/__jac/") {
        named = r.path.split("/");
        if call and not trusted and len(named) == 6 {
            often = too_often(limited(named[4], named[5], caller, r.client));
            if often is not None {
                return often;
            }
        }
        return stream_of(answer_stream(r.path, r.body, caller, trusted));
    }
    route = route_of(r.method, r.path);
    if route is not None {
        if not trusted {
            often = too_often(limited(route.module, route.name, caller, r.client));
            if often is not None {
                return often;
            }
        }
        (status, ctype, body) = route_answer(route, caller, trusted);
        return Response(status=status, ctype=ctype, body=body);
    }
    # Each page the app serves, from its artifact (pages/<page>/ beside the
    # program), the one at the longest base that holds the path first.
    pages = sorted(p.pages, key=lambda (g: Page) -> int { return -len(g.base); });
    served = os.environ.get(DEV_SERVED, "");
    for g in pages {
        if g.space == served {
            continue;
        }
        files = os.path.join(os.path.dirname(sys.executable), "pages", g.space);
        if g.base == "/" {
            return static_file(files, r.path);
        }
        if r.path.startswith(g.base) or r.path == g.base.rstrip("/") {
            return static_file(files, r.path[len(g.base):] if len(r.path) > len(g.base) else "/");
        }
    }
    # An app that serves no page at a path serves no files there.
    return Response(status=404, ctype="text/plain", body=b"not found");
}

"""Refuse to start (CannotStart) a program that serves something at a path (a
function's own, a page) when the project's transport carries calls alone:
said as it starts, never as a path is first asked for."""
def refuse_unserved {
    if transport().serves_paths() {
        return;
    }
    p = plan();
    wants = [f"`{r.module}.{r.name}` at {r.path}" for r in routes()] + [
        f"the page space `{g.space}` at {g.base}"
        for g in p.pages
    ];
    if len(wants) == 0 {
        return;
    }
    raise CannotStart(
        why=f"{p.app} can't start with the transport it was given: it serves {', '.join(wants)}, and that transport carries calls and serves no paths. Bind one that serves them in jac.toml's [transport], or pick it where the program runs with JAC_TRANSPORT.",
    );
}

"""Start the program as its plan says."""
def start {
    p = plan();
    if p.carried {
        # Served through the program that runs it: its own graph, its jobs
        # in copies of that program (stdjac.cpython_space set how).
        open_data(False);
        return;
    }
    if ran_job() {
        # A copy the project's jobs started for one: its job, then it ends.
        sys.exit(0);
    }
    if p.has_entry {
        # The program's own code runs next: it listens for nothing, so its
        # scheduled functions don't run.
        ready();
        return;
    }
    win = p.window;
    if win is not None {
        # The copy of the program that is its window shows it, and ends.
        w: Window = win;
        window_host().run_asked(w.title, w.width, w.height, w.min_width, w.min_height);
    }
    refuse_unserved();
    # Its address before anything else: a copy started where another one
    # listens can't start, and leaves the data that one keeps as it is.
    claim = claim_address(win is not None);
    work = ready();
    ticks: list[Tick] = [];
    if win is not None {
        wh = window_host();
        ticks.append(
            Tick(
                name="window",
                every=0.5,
                run=lambda {
                    wh.watch();
                    if len(_relaunch) > 0 {
                        wh.relaunch();
                    }
                },
            ),
        );
    }
    if win is None or len(p.spaces) > 0 {
        open_data(True);
    }
    # The calls are at the graph's store one at a time.
    storing = threading.RLock();
    store_in_turn(
        lambda (work: Callable[[], None]) {
            with storing {
                work();
            }
        },
    );
    start_schedule(work, on_loop);
    if win is not None {
        # The window is opened at the port its server took.
        transport().listen(claim, handle, ticks, window_host().open);
    } else {
        transport().listen(claim, handle, ticks, None);
    }
}

"""Ready what the program runs, whether it listens or not: the app's data set
aside when it was asked to start with none, and each space it runs in its own
process. Its spaces' scheduled functions, and theirs."""
def ready -> list[Scheduled] {
    p = plan();
    set_aside(data_dir());
    # (A space this arrangement doesn't run schedules nothing.)
    work = scheduled() if len(p.spaces) > 0 else [];
    for h in p.hosted {
        # A space it runs in its own process, from its code beside the
        # program, where its plan says (JAC_<SPACE>_CODE elsewhere): its calls to the program's
        # own spaces come back through in_process.
        work = work + space_host(h.host).start(h.space, space_code(h.space), p.spaces, in_process);
    }
    return work;
}

with entry {
    try {
        start();
    } except CannotStart as e {
        sys.stderr.write(e.why + "\n");
        sys.exit(1);
    }
}
