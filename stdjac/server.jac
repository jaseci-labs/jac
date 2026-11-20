"""What a served program is made of, beside its endpoints: who its
callers are, the functions it serves at paths of their own, the ones it runs
on a schedule, its jobs and its limits. Each is an abstraction: what source
says of it is here, with the interface its plugin conforms to, and what
carries it out is the plugin the project binds in jac.toml.

| Source says | Its interface | Standard plugin |
|---|---|---|
| `:protect`, the caller's `root`, a page's `sign_in()` | `Auth` | `accounts` |
| `@job`, `flow f(x)`, `wait j` | `Jobs` | `process-jobs` |
| `@schedule(interval=60.0)` | `Scheduler` | `loop-schedule` |
| `@limit(5, per=900.0)`, `consume_limit(...)` | `Limits` | `memory-limits` |

`@restspec`, `@schedule`, `@job` and `@limit` are decorators: each leaves a
note on its function as the program compiles, and what serves the program
reads the notes of every function that carries one. Nothing is registered as
a module starts."""

import hmac;
import json;
import os;
import sys;
import time;
import from jaclang.comptime { apply, args_type, note, noted, params, restore, set_field }

# ---- who is calling: auth

"""Something a caller gives to sign in: its `name`, what a page calls it,
whether it is kept from sight as it is typed, and, when only some values are
taken, which."""
obj:pub SignInField {
    has name: str,
        label: str = "",
        secret: bool = False,
        choices: list[str] = [];
}

"""A way of signing in a page offers: its `name`, which `Auth.answer` is
given, what a page calls it, and the fields it takes; or, for one done
elsewhere, the place to go, `redirect`, from which the caller comes back to
`/__jac/auth/<name>` with what that place gave them. What `keeps` holds
stays with the page that left, and is given to `Auth.answer` beside what the
caller came back with: so a plugin can tell the caller who left from one who
was only handed the way back."""
obj:pub SignInAction {
    has name: str,
        label: str = "",
        needs: list[str] = [],
        redirect: str = "",
        keeps: dict[str, str] = {};
}

"""A caller signed in: who they are, the credential their calls carry from
now on ("" where the plugin knows a caller by something else its requests
carry), and what they are called, where that is not who they are (the name
another service knows them by)."""
obj:pub Session {
    has user: str,
        token: str = "",
        name: str = "";
}

"""What signing in takes, as a page shows it: a form of `fields` with its
`actions`; or a place to go, `redirect`; or nothing, for a caller the plugin
knows already, whose `session` it is."""
obj:pub SignIn {
    has fields: list[SignInField] = [],
        actions: list[SignInAction] = [],
        redirect: str = "",
        session: Session | None = None;
}

"""A sign-in the plugin refuses, saying why: and, for one made too often, how
many seconds to wait."""
obj:pub Rejected(Exception) {
    has detail: str,
        retry_after: int = 0;

    def __str__ -> str {
        return self.detail;
    }
}

"""Who a caller is, and how one signs in: the interface of the `auth`
abstraction's plugins. `headers` are a request's, their names lowercased.

- `caller` is who a request's caller is, or None for one it does not know.
- `asks` is what signing in takes, for a page to show.
- `answer` signs a caller in by `action` with what they gave, from the
  client at `client`: their session, or Rejected.
- `leave` ends the session a request carries."""
obj:pub Auth {
    def open abst;
    def caller(headers: dict[str, str]) -> str | None abst;
    def asks(headers: dict[str, str]) -> SignIn abst;
    def answer(action: str, given: dict[str, str], client: str) -> Session abst;
    def leave(headers: dict[str, str]) abst;
}

glob _auth: list[dyn Auth] = [];

"""The project's auth, opened: DataError for data it keeps that it can't
start with. A program that serves calls it as it starts."""
def:pub open_auth {
    a: dyn Auth = bound("auth");
    a.open();
    _auth.append(a);
}

"""Who the caller of a request with `headers` is: "" for one no one knows,
and in a program with no auth."""
def:pub auth_caller(headers: dict[str, str]) -> str {
    if len(_auth) == 0 {
        return "";
    }
    who = _auth[0].caller(headers);
    return who if who is not None else "";
}

"""The credential a request with `headers` carries as a bearer token, or ""."""
def:pub bearer_token(headers: dict[str, str]) -> str {
    return headers.get("authorization", "").removeprefix("Bearer ").strip();
}

"""Whether `r` is signed with this deployment's key (`JAC_DEPLOY_KEY`, never
baked in), so another app of the deployment made it: compared in constant
time, and never with no key set."""
def:pub deployment_signed(r: Request) -> bool {
    key = os.environ.get("JAC_DEPLOY_KEY", "");
    given = r.headers.get("x-jac-key", "");
    return key != "" and hmac.compare_digest(given.encode("utf-8"), key.encode("utf-8"));
}

def:pub json_ok(data: any) -> Response {
    return Response(body=json.dumps({"ok": True, "data": data}).encode("utf-8"));
}

def:pub json_fail(status: int, kind: str, detail: str) -> Response {
    return Response(
        status=status,
        body=json.dumps({"ok": False, "kind": kind, "detail": detail}).encode("utf-8"),
    );
}

"""What `asks` is, as JSON's values."""
def asked(a: SignIn) -> dict[str, any] {
    s = a.session;
    return {
        "fields": [
            {"name": f.name, "label": f.label, "secret": f.secret, "choices": f.choices}
            for f in a.fields
        ],
        "actions": [
            {
                "name": x.name,
                "label": x.label,
                "needs": x.needs,
                "redirect": x.redirect,
                "keeps": x.keeps,
            }
            for x in a.actions
        ],
        "redirect": a.redirect,
        "session": signed(s) if s is not None else None,
    };
}

"""What a session is, as JSON's values."""
def signed(s: Session) -> dict[str, any] {
    return {"user": s.user, "token": s.token, "name": s.name};
}

"""The page a caller comes back to from the place a way of signing in sent
them: it answers that way with what they came back with and what the page
that left kept, keeps the session where the page's runtime reads it, and
goes back to where they left from. It is the same for every plugin, and
holds nothing of the request."""
glob CAME_BACK: str = """<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Signing in</title>
<body>
<script>
(async () => {
    let kept = {};
    try {
        kept = JSON.parse(sessionStorage.getItem("jac_sign_in") || "{}") || {};
        sessionStorage.removeItem("jac_sign_in");
    } catch (_) {}
    const given = Object.assign({}, Object.fromEntries(new URLSearchParams(location.search)), kept.keeps || {});
    let said = "the app could not be reached";
    try {
        const res = await fetch(location.pathname, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(given) });
        const data = await res.json();
        if (data.ok) {
            if (data.data.token) localStorage.setItem("jac_token", data.data.token);
            if (data.data.name) localStorage.setItem("jac_name", data.data.name);
            else localStorage.removeItem("jac_name");
            // (Back to a path of this origin, and nowhere else.)
            const b = kept.back;
            const back = typeof b === "string" && b[0] === "/" && b[1] !== "/" && b.charCodeAt(1) !== 92 ? b : "/";
            location.replace(back);
            return;
        }
        said = data.detail;
    } catch (_) {}
    const p = document.createElement("p");
    p.textContent = "Signing in did not work: " + said + ". ";
    const home = document.createElement("a");
    home.href = "/";
    home.textContent = "Go back";
    p.appendChild(home);
    document.body.appendChild(p);
})();
</script>
""";

"""What answers a request under `/__jac/auth/`, with the project's auth:

- `GET /__jac/auth/`: what signing in takes.
- `GET /__jac/auth/me`: who the caller is, or 401.
- `POST /__jac/auth/logout`: the caller's session is ended.
- `POST /__jac/auth/<action>`, a JSON object of strs: the caller is signed in
  by that action, and answered their session.
- `GET /__jac/auth/<action>?...`: where another service sends a caller back
  with what it gave them. It is answered a page, which posts that and what
  the page they left from kept to the line above, and keeps the session.

A sign-in the plugin refuses is 400 `rejected` with its reason, and 429 with
`Retry-After` for one made too often."""
def:pub auth_route(r: Request) -> Response {
    if len(_auth) == 0 {
        return json_fail(500, "failed", "no accounts");
    }
    a = _auth[0];
    action = r.path.removeprefix("/__jac/auth").lstrip("/");
    if r.method == "GET" and action == "" {
        return json_ok(asked(a.asks(r.headers)));
    }
    if action == "me" {
        who = a.caller(r.headers);
        if who is None {
            return json_fail(401, "rejected", "not signed in");
        }
        return json_ok({"user": who});
    }
    if action == "logout" {
        a.leave(r.headers);
        return json_ok(None);
    }
    if r.method == "GET" {
        return Response(ctype="text/html; charset=utf-8", body=CAME_BACK.encode("utf-8"));
    }
    b: any = None;
    try {
        b = json.loads(r.body.decode("utf-8"));
    } except ValueError {
        b = None;
    }
    if not isinstance(b, dict) {
        return json_fail(400, "rejected", "the request is not a JSON object");
    }
    sent: dict[str, any] = b;
    given: dict[str, str] = {str(k): str(v) for (k, v) in sent.items()};
    try {
        return json_ok(signed(a.answer(action, given, r.client)));
    } except Rejected as no {
        failed = json_fail(429 if no.retry_after > 0 else 400, "rejected", no.detail);
        if no.retry_after > 0 {
            failed.headers = {"Retry-After": str(no.retry_after)};
        }
        return failed;
    }
}

# ---- limits

"""What counts uses: the interface of the `limits` abstraction's plugins.
`consume` counts a use of `scope` by `actor`, and gives 0 while that is
within `limit` uses in `seconds`, else the seconds until it is."""
obj:pub Limits {
    def consume(scope: str, actor: str, limit: int, seconds: int) -> int abst;
}

glob _limits: list[dyn Limits] = [];

"""Counts a use of `scope` by `actor`: 0 while it is within `limit` uses in
`seconds`, else how many seconds until it is."""
def:pub consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int {
    if len(_limits) == 0 {
        l: dyn Limits = bound("limits");
        _limits.append(l);
    }
    return _limits[0].consume(scope, actor, limit, seconds);
}

"""`@limit(5, per=900.0)` before an endpoint: a caller may call it `uses`
times in each `per` seconds, a caller no one knows counted by the address
they call from. A call past that is refused as `rejected`, with the seconds
to wait."""
comptime def limit(f: Callable, uses: int, per: float) {
    comptime assert uses > 0, "@limit takes how many uses, at least one";
    comptime assert per > 0.0, "@limit takes the seconds they are counted in";
    note(f, "limit", (uses, per));
}

"""Each limited function's limit, by its module and name: its uses, and the
seconds they are counted in."""
glob _limited: dict[str, tuple[int, int]] = {},
     _limits_read: list[bool] = [];

"""How long `caller` waits before `module`.`name` may be called again, which
counts this call: 0 for a call within the function's limit, and for a
function with none. A caller no one knows ("") is counted by `client`,
where their request came from."""
def:pub limited(module: str, name: str, caller: str, client: str) -> int {
    if len(_limits_read) == 0 {
        _limits_read.append(True);
        comptime for n in noted("limit") {
            _limited[n.module + "." + n.name] = (n.value[0], int(n.value[1]));
        }
    }
    key = module + "." + name;
    if key not in _limited {
        return 0;
    }
    (uses, seconds) = _limited[key];
    actor = "caller " + caller if caller != "" else "client " + client;
    return consume_limit("endpoint " + key, actor, uses, seconds);
}

# ---- a path of its own: restspec

enum HTTPMethod {
    GET = "GET",
    POST = "POST",
}

"""`@restspec(method=HTTPMethod.GET, path="/robots.txt")` before a function
of no parameters: it is served at `path` for `method`, beside its endpoint's
own address, to the callers its access tag admits. Its reply is the JSON
envelope, or, with `envelope=False`, its result, a str, as `produces`."""
comptime def restspec(
    f: Callable, method: HTTPMethod, path: str, produces: str = "text/plain", envelope: bool = True
) {
    comptime assert len(params(f))
        == 0, "a function served at a path of its own takes no parameters";
    comptime assert len(path) > 0 and path[0] == "/", "@restspec's path starts with '/'";
    note(f, "restspec", (method, path, produces, envelope));
}

"""A function served at a path of its own: for `method`, as `produces` says
(its result as the body, a str, without the `envelope`). `run` calls it."""
obj:pub RestRoute {
    has method: HTTPMethod,
        path: str,
        produces: str,
        envelope: bool,
        module: str,
        name: str,
        run: Callable[[], any];
}

glob _routes: list[RestRoute] = [],
     _routes_read: list[bool] = [];

"""Every function of the program served at a path of its own."""
def:pub routes -> list[RestRoute] {
    if len(_routes_read) == 0 {
        _routes_read.append(True);
        comptime for n in noted("restspec") {
            _routes.append(
                RestRoute(
                    method=n.value[0],
                    path=n.value[1],
                    produces=n.value[2],
                    envelope=n.value[3],
                    module=n.module,
                    name=n.name,
                    run=lambda -> any {
                        a = restore(args_type(n.decl));
                        return apply(n.decl, a);
                    },
                ),
            );
        }
    }
    return _routes;
}

"""The route a request for `method` and `path` asks for, if any."""
def:pub route_of(method: str, path: str) -> RestRoute | None {
    for r in routes() {
        if r.path == path and r.method.value == method {
            return r;
        }
    }
    return None;
}

"""What route `r` answers `caller`, `trusted` when another app of the
deployment signed the request: through its function's endpoint, which says who
may call and how its result is encoded, when the function is one; else as the
deployment's own. Its status, its body's type and its body."""
def:pub route_answer(r: RestRoute, caller: str, trusted: bool) -> tuple[int, str, bytes] {
    e = endpoint_named(r.module, r.name);
    status = 200;
    reply = b"";
    if e is not None {
        (status, reply) = answer(e.path(), b"", caller, trusted);
    } else {
        if not trusted {
            (status, reply) = reply_fail(403, "rejected", "an internal endpoint");
        } else {
            try {
                out: any = kept_call(caller, lambda -> any { return json_values(r.run()); });
                reply = json.dumps({"ok": True, "data": out}).encode("utf-8");
            } except Exception as x {
                print(f"route {r.path} failed: {type(x).__name__}: {x}");
                (status, reply) = reply_fail(500, "failed", r.path + " failed");
            }
        }
    }
    if r.envelope or status != 200 {
        return (status, "application/json", reply);
    }
    data: any = json.loads(reply.decode("utf-8"))["data"];
    if not isinstance(data, str) {
        print(
            f"route {r.path} failed: its function gives a {type(data).__name__}, not the str its body is",
        );
        (status, reply) = reply_fail(500, "failed", r.path + " failed");
        return (status, "application/json", reply);
    }
    text: str = data;
    return (200, r.produces, text.encode("utf-8"));
}

# ---- scheduled functions

"""`@schedule(interval=60.0)` before a function of no parameters that gives
nothing, or an `async def` of none: a program that serves runs it every
`interval` seconds, the first time as it starts."""
comptime def schedule(f: Callable, interval: float) {
    comptime assert len(params(f)) == 0, "a scheduled function takes no parameters";
    comptime assert interval > 0.0, "@schedule's interval is a number of seconds, more than none";
    note(f, "schedule", interval);
}

"""A scheduled function: its `name` (its module's and its own), how often it
runs, and `run`, which runs it once: for no caller, with what it changed in
the graph kept."""
obj:pub Scheduled {
    has name: str,
        every: float,
        run: Callable[[], None];
}

"""What runs a program's scheduled functions when they are due: the
interface of the `schedule` abstraction's plugins. `start` is given each,
and `on_loop`, which has the thread the program listens on run a piece of
work: where a scheduled function of a space the program runs in its own
process must run."""
obj:pub Scheduler {
    def start(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None]) abst;
}

"""Run scheduled function `f` once. It runs for no caller: `root` is the
shared one, whoever the last call served was for. An `async def`'s coroutine
is run to its end (`settle`), and what it changed in the graph is kept."""
def run_scheduled(f: Callable[[], any]) {
    kept_call(
        "",
        lambda -> any {
            settle(f());
            return None;
        },
    );
}

"""Every scheduled function of the program, but those `JAC_TICKS_OFF` names
where it runs (`all`, or names separated by commas)."""
def:pub scheduled -> list[Scheduled] {
    out: list[Scheduled] = [];
    off = os.environ.get("JAC_TICKS_OFF", "").split(",");
    comptime for n in noted("schedule") {
        if "all" not in off and n.module + "." + n.name not in off and n.name not in off {
            out.append(
                Scheduled(
                    name=n.module + "." + n.name,
                    every=n.value,
                    run=lambda {
                        run_scheduled(
                            lambda -> any {
                                a = restore(args_type(n.decl));
                                return apply(n.decl, a);
                            },
                        )
                    },
                ),
            );
        }
    }
    return out;
}

"""Have the project's scheduler run `work`."""
def:pub start_schedule(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None]) {
    if len(work) == 0 {
        return;
    }
    s: dyn Scheduler = bound("schedule");
    s.start(work, on_loop);
}

# ---- jobs

"""`@job` before a function of its input and a `note(phase, text)`: it runs
apart from what starts it. `flow f(x)` starts it and gives a `Job`, at once;
`wait j` gives its result. Its input and its result cross to where it runs
and back as a crossing's values do, and it sees nothing of the graph of
what started it."""
comptime def job(f: Callable) {
    comptime assert len(params(f)) == 2, "a job's function takes its input and a note(phase, text)";
    note(f, "job", None);
}

"""What a job says of how it goes: a phase, and a line of it."""
type JobNote = Callable[[str, str], None];

"""What a job has said since it was last read, and its end: whether it has
ended, with its result as JSON's values, or what it failed with."""
obj:pub JobState {
    has notes: list[tuple[str, str]] = [],
        done: bool = False,
        result: any = None,
        failed: str = "";
}

"""What runs a program's jobs apart: the interface of the `jobs`
abstraction's plugins.

- `start` starts job `name` (its module's and its own) on `input`, JSON's
  values, and gives what names that run.
- `read` gives what run `id` has said since it was last read, and whether
  it has ended.
- `work` is asked as a program starts: it runs the job this process was
  started for, if it was started for one, and says whether it was."""
obj:pub Jobs {
    def start(name: str, input: any) -> str abst;
    def read(id: str) -> JobState abst;
    def work -> bool abst;
}

glob _jobs: list[dyn Jobs] = [];

"""The project's jobs plugin."""
def:pub jobs -> dyn Jobs {
    if len(_jobs) == 0 {
        j: dyn Jobs = bound("jobs");
        _jobs.append(j);
    }
    return _jobs[0];
}

"""The command that runs this program again, and the space whose jobs they
are to a copy of it: this process's own command line and "", unless it was
told otherwise. A space another program of the app runs in its process is
told that program's command and its own name (stdjac.cpython_space)."""
glob _job_command: list[str] = [],
     _job_owner: str = "";

"""Run jobs as `command` (this program again) rather than as this process's
command line says, each for the space `owner`."""
def:pub set_job_command(command: list[str], owner: str) {
    _job_command.clear();
    for c in command {
        _job_command.append(c);
    }
    _job_owner = owner;
}

"""The command that runs this program again: before its arguments (on
CPython, the interpreter and its script), unless it was told what runs it."""
def:pub job_command -> list[str] {
    if len(_job_command) > 0 {
        return list(_job_command);
    }
    return sys.orig_argv[0:len(sys.orig_argv) - len(sys.argv) + 1];
}

"""The space whose jobs this program's are, to a copy started for one: ""
for the program's own."""
def:pub job_owner -> str {
    return _job_owner;
}

"""A job that failed: what `wait j` raises, with what the job failed with."""
obj:pub JobFailed(Exception) {
    has detail: str;

    def __str__ -> str {
        return self.detail;
    }
}

"""A job started (`flow f(x)` of a `@job` function), whose result is an R.

- `done()` is whether it has ended, without waiting.
- `notes()` is what it has said since `notes()` was last called.
- `wait j` is its result, waited for (`job_result`): JobFailed for one that
  failed."""
obj:pub Job[R] {
    has id: str,
        said: list[tuple[str, str]] = [],
        ended: bool = False,
        got: any = None,
        failed: str = "";

    def read {
        if self.ended {
            return;
        }
        st = jobs().read(self.id);
        for n in st.notes {
            self.said.append(n);
        }
        if st.done {
            self.ended = True;
            self.got = st.result;
            self.failed = st.failed;
        }
    }

    def done -> bool {
        self.read();
        return self.ended;
    }

    def notes -> list[tuple[str, str]] {
        self.read();
        out = self.said;
        self.said = [];
        return out;
    }

    """Its result as JSON's values, waited for: JobFailed for a job that
    failed."""
    def settled -> any {
        while not self.done() {
            time.sleep(0.05);
        }
        if self.failed != "" {
            raise JobFailed(detail=self.failed);
        }
        return self.got;
    }
}

"""What `wait j` is, of a job: its result, an R, waited for."""
def:pub job_result[R](j: Job[R]) -> R {
    return decode[R](j.settled());
}

"""What `flow f(x)` of the job `name` is: the job started on `input`."""
def:pub start_job[R, I](name: str, input: I) -> Job[R] {
    return Job[R](id=jobs().start(name, encode[I](input)));
}

"""Run this program's job `name` on `input`, JSON's values, telling `note`
how it goes: its result, as JSON's values. ValueError for a name that is no
job's. What a jobs plugin calls where the job runs."""
def:pub run_job(name: str, input: any, note: Callable[[str, str], None]) -> any {
    comptime for n in noted("job") {
        if name == n.module + "." + n.name {
            run = lambda (v: any) -> any {
                a = restore(args_type(n.decl));
                comptime ps = params(n.decl);
                comptime i = ps[0];
                comptime k = ps[1];
                set_field(a, i.name, decode[i.type](v));
                set_field(a, k.name, note);
                return encode(apply(n.decl, a));
            };
            return run(input);
        }
    }
    raise ValueError(f"no job '{name}' in this program");
}

# ---- the spaces and the window a program hosts

"""How a native app runs a space of another host in its own process:
`start` starts a space from its code's directory, given the spaces the app's
own code is and the port they're reached through, and gives its scheduled
functions; `job` runs one of a space's jobs in a copy of the program, given
the space, its code's directory, the job's name, its input as JSON's values
and a `note(phase, text)`, and gives its result. Its module registers it as
it starts (stdjac.cpython_space, stdjac.node_space)."""
obj:pub SpaceHost {
    has start: Callable[[
            str,
            str,
            list[str],
            Callable[[str, bytes, str, bool], tuple[int, bytes]],
        ], list[Scheduled]],
        job: Callable[[str, str, str, any, Callable[[str, str], None]], any] | None = None;
}

"""How an app that runs a browser space shows it: in a window, which runs in a
copy of the program (stdjac.desktop registers it as it starts). `run_asked`
shows the window and exits, in that copy; `open` starts that copy, given the
port the program serves on; `watch` ends the program when the window has
closed, with a failure when that copy ended with one."""
obj:pub WindowHost {
    has run_asked: Callable[[str, int, int, int, int], None],
        open: Callable[[int], None],
        watch: Callable[[], None],
        # Close the window and start the program again in its place: what
        # an app does when its user chooses another arrangement of it.
        relaunch: Callable[[], None];
}

glob _window_host: list[WindowHost] = [];

def:pub register_window_host(h: WindowHost) -> bool {
    _window_host.append(h);
    return True;
}

def:pub window_host -> WindowHost {
    if len(_window_host) == 0 {
        raise RuntimeError("this program shows no window");
    }
    return _window_host[0];
}

glob _space_hosts: dict[str, SpaceHost] = {};

def:pub register_space_host(host: str, h: SpaceHost) -> bool {
    _space_hosts[host] = h;
    # (A space it runs may have jobs, which run in copies of this program.)
    _hosted_jobs.append(lambda -> bool { return jobs().work(); });
    return True;
}

"""What says whether this program is a copy started for a job of a space it
runs in its own process: set as a host of such spaces registers."""
glob _hosted_jobs: list[Callable[[], bool]] = [];

"""Whether this program is a copy its jobs started for one, having run it:
asked as a program starts. A program with no job of its own, which runs no
space that may have one, asks nothing of the `jobs` plugin, and is built
without it."""
def:pub ran_job -> bool {
    comptime for n in noted("job") {
        return jobs().work();
    }
    for hosted in _hosted_jobs {
        return hosted();
    }
    return False;
}

def:pub space_host(host: str) -> SpaceHost {
    if host not in _space_hosts {
        raise RuntimeError(f"this program runs no {host} space in its process");
    }
    return _space_hosts[host];
}

"""Run job `name` of the space `owner`, which this program runs in its own
process, on `input`, JSON's values, telling `note` how it goes: its result.
What a jobs plugin calls where a space's job runs. ValueError for a space
this program runs none of."""
def:pub run_space_job(owner: str, name: str, input: any, note: Callable[[str, str], None]) -> any {
    for h in plan().hosted {
        runs = space_host(h.host).job if h.space == owner else None;
        if runs is not None {
            runner: Callable[[str, str, str, any, Callable[[str, str], None]], any] = runs;
            return runner(owner, space_code(owner), name, input, note);
        }
    }
    raise ValueError(f"this program runs no jobs of a space '{owner}'");
}

# ---- files a program serves

glob CONTENT_TYPES: dict[str, str] = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".json": "application/json",
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".ico": "image/x-icon",
    ".woff": "font/woff",
    ".woff2": "font/woff2",
    ".ttf": "font/ttf",
    ".txt": "text/plain; charset=utf-8",
    ".wasm": "application/wasm",
    ".map": "application/json",
    ".md": "text/markdown; charset=utf-8",
};

"""A file under the directory `top`, or its page (`index.html`) for a route it
doesn't name. Only what is under `top` once links are followed is served: a
path out of it, by `..` or by a link, is refused."""
def:pub static_file(top: str, path: str) -> Response {
    if top == "" {
        # An empty directory would be the working directory's.
        raise ValueError("static_file needs the directory it serves");
    }
    served = os.path.realpath(top);
    full = os.path.realpath(os.path.join(served, path.lstrip("/")));
    under = False;
    try {
        under = os.path.commonpath([served, full]) == served;
    } except ValueError {
        # (On another drive, on Windows.)
        under = False;
    }
    if not under {
        return Response(status=403, ctype="text/plain", body=b"forbidden");
    }
    rel: str = os.path.relpath(full, served);
    if rel == "." or not os.path.isfile(full) {
        # A missing file of a kind this serves is missing. Anything else is a page's
        # route, which may have a dot in it: `/docs/v0.39`.
        ext = os.path.splitext(rel)[1].lower();
        page = os.path.join(served, "index.html");
        if ext in CONTENT_TYPES and ext != ".html" or not os.path.isfile(page) {
            return Response(status=404, ctype="text/plain", body=b"not found");
        }
        full = page;
        rel = "index.html";
    }
    with open(full, "rb") as f {
        data = f.read();
    }
    extra: dict[str, str] = {};
    if rel.split(os.sep)[0] == "assets" {
        # The bundler's assets, named by their content.
        extra["Cache-Control"] = "public, max-age=31536000, immutable";
    }
    return Response(
        ctype=CONTENT_TYPES.get(os.path.splitext(full)[1].lower(), "application/octet-stream"),
        body=data,
        headers=extra,
    );
}
