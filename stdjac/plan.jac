"""What a program of an app is: the data its build records, the same
library code reading it in every app. `jac build` computes it from the
archwire and jac.toml for each program it makes and bakes it in; outside an
app's build a program has none, and `plan()` is the empty one.

Every deployment value has its environment variable, which a deployment
sets to override what was baked in: `JAC_<APP>_LISTEN`, `JAC_<APP>_DATA`,
`JAC_REMOTE_<SPACE>`."""

import json;
import os;
import sys;

import from jac {
    def __app_plan -> str;
}

"""A browser space the app serves: its bundle at `pages/<space>` beside the
program, at the URL path `base`."""
obj Page {
    has space: str,
        base: str = "/";
}

"""A space the program runs in its own process on another host: a cpython
space in embedded CPython, a node space in embedded Node."""
obj Hosted {
    has space: str,
        host: str,
        # Where its code is, from the program's directory: under its npm
        # tree's packages when it has a tree, as its modules are in the
        # project, so they find them as they find any package.
        code: str = "";
}

"""The desktop window of an app that runs a browser space."""
obj Window {
    has title: str,
        width: int = 1280,
        height: int = 860,
        min_width: int = 640,
        min_height: int = 480;
}

obj AppPlan {
    has app: str = "",
        # The spaces this program's own code is.
        spaces: list[str] = [],
        # Whether it is one space another program of the app runs in its
        # process (a cpython space in embedded CPython), serving through it.
        carried: bool = False,
        # Whether the program has an entry, which runs after it starts; else
        # it serves.
        has_entry: bool = False,
        hosted: list[Hosted] = [],
        pages: list[Page] = [],
        # Each endpoint a served page may reach that the app doesn't run,
        # by its path: the space it is for.
        forwarded: dict[str, str] = {},
        # Where each space the program reaches and doesn't run is, as
        # jac.toml's [apps.<app>.remote] says.
        remotes: dict[str, str] = {},
        # Where a window's sign-in goes, for an app that runs no space of
        # its own: the space whose app keeps its accounts.
        accounts: str = "",
        window: Window | None = None,
        # Where the app keeps its graph, accounts and jobs.
        data_dir: str = "",
        # Which arrangement of the app this plan is, of those its one
        # artifact holds (jac.toml's `[apps.<app>] profiles`): "" for an app
        # with one. The artifact's first plan holds the `others`.
        arrangement: str = "",
        others: list[AppPlan] = [],
        # Every arrangement the artifact holds, and whether this one was
        # chosen (else it is the first, which the app starts as): set as the
        # plan is read.
        arrangements: list[str] = [],
        chosen: bool = True;
}

glob _plan: list[AppPlan] = [];

"""This program's plan, as its build recorded it: of the arrangements its
artifact holds, the one chosen where it runs."""
def:pub plan -> AppPlan {
    if len(_plan) == 0 {
        text = __app_plan();
        _plan.append(arranged(decode[AppPlan](json.loads(text))) if text != "" else AppPlan());
    }
    return _plan[0];
}

"""Where the app whose plan is `p` keeps what it keeps: JAC_<APP>_DATA, else
where its build said."""
def:pub app_data(p: AppPlan) -> str {
    return os.environ.get(env_name(p.app, "DATA"), p.data_dir);
}

"""Where this program keeps what it keeps beside itself: its app's data
directory, and a directory of its own there for a space another program of
the app runs in its process. A plugin that keeps a file keeps it here."""
def:pub data_dir -> str {
    p = plan();
    d = app_data(p);
    return os.path.join(d, p.spaces[0]) if p.carried else d;
}

"""Where an app of several arrangements keeps which one its user chose."""
def arrangement_file(p: AppPlan) -> str {
    return os.path.join(app_data(p), "arrangement");
}

"""Of the plans an artifact holds, `first` and its `others`, the one this
run is: the arrangement JAC_<APP>_ARRANGEMENT names, else the one the app's
user chose, kept with its data, else the first."""
def arranged(first: AppPlan) -> AppPlan {
    if len(first.others) == 0 {
        return first;
    }
    held = [first] + first.others;
    want: str = os.environ.get(env_name(first.app, "ARRANGEMENT"), "");
    if want == "" {
        try {
            with open(arrangement_file(first)) as f {
                want = f.read().strip();
            }
        } except OSError {
            want = "";
        }
    }
    picked = first;
    chosen = False;
    for p in held {
        if p.arrangement == want {
            picked = p;
            chosen = True;
        }
    }
    picked.arrangements = [p.arrangement for p in held];
    picked.chosen = chosen;
    return picked;
}

"""The app's user chose arrangement `name`: what it is when it next starts.
ValueError for a name that is none of its arrangements'."""
def:pub keep_arrangement(name: str) {
    p = plan();
    if name not in p.arrangements {
        raise ValueError(
            f"{p.app} has no arrangement '{name}': it may be {', '.join(p.arrangements)}"
        );
    }
    os.makedirs(app_data(p), exist_ok=True);
    with open(arrangement_file(p), "w") as f {
        f.write(name + "\n");
    }
}

"""The name of the environment variable for `what` of `app`: uppercased, and a
character a variable's name can't hold made `_`."""
def:pub env_name(app: str, what: str) -> str {
    out = "";
    for ch in ("JAC_" + app + "_" + what).upper() {
        out += ch if ch.isalnum() else "_";
    }
    return out;
}

"""Where the space `space` this program reaches is: JAC_REMOTE_<SPACE>, else
what the build baked in, else ""."""
def:pub remote_url(space: str) -> str {
    return os.environ.get(env_name("REMOTE", space), plan().remotes.get(space, ""));
}

"""Where the program finds the code of space `space`, which it runs in its
own process: where its plan says, beside the program, or JAC_<SPACE>_CODE."""
def:pub space_code(space: str) -> str {
    code = "";
    for h in plan().hosted {
        if h.space == space {
            code = h.code;
        }
    }
    return os.environ.get(
        env_name(space, "CODE"), os.path.join(os.path.dirname(sys.executable), code)
    );
}
