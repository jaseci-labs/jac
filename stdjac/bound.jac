"""The plugins a program was built with, and the one of each
abstraction it runs with.

A project's jac.toml names, for each abstraction, the plugins it may use and
their settings. The build compiles each of them in: where a module of stdjac
asks for an abstraction's plugin, `bound("store")`, it adds what makes each
listed plugin with the settings jac.toml gives it, and `bound` picks among
them: the one `JAC_<ABSTRACTION>` names where the program runs, else the one
jac.toml's `plugin` names. Nothing is loaded as the program runs.

A setting is a field of the plugin's class. `settle` overrides each from
`JAC_<ABSTRACTION>_<FIELD>`, read as the field's type; a field of type
`Secret` is never given in jac.toml, and is read from the environment when
the plugin asks for it."""

import json;
import os;
import sys;
import from jaclang.comptime { Kind, fields, kind, set_field }

"""A setting that is never written down: an API's key, a database's password.
A plugin declares the field with the variable its service's users already
set (`has key: Secret = Secret(variable="ANTHROPIC_API_KEY");`), and
`JAC_<ABSTRACTION>_<FIELD>` names another where the program runs."""
obj:pub Secret {
    has variable: str = "";

    """Whether the place the program runs gives it."""
    def given -> bool {
        return os.environ.get(self.variable, "") != "";
    }

    """What it is, where the program runs: ValueError where it is not given."""
    def get -> str {
        v = os.environ.get(self.variable, "");
        if v == "" {
            raise ValueError(f"{self.variable} isn't set");
        }
        return v;
    }
}

"""The plugins a program was built with for one abstraction: the variables
that pick among them and override their settings where the program runs
(most particular first, without what follows them: `JAC_API_STORE`), their
names as jac.toml lists them, the one it names, and what makes each."""
obj:pub Offers {
    has variables: list[str],
        listed: list[str],
        named: str,
        makers: list[Callable[[], any]];
}

"""The plugin each abstraction runs with, once it was asked for."""
glob _made: dict[str, any] = {};

"""The plugin `abstraction` runs with, made the first time it is asked for.

A module of stdjac writes `bound("store")`, and the build gives the call its
second argument: what makes the offers, from the project's jac.toml. So a
program holds the plugins of the abstractions it asks for, and no others.

The plugin is the one a variable of the abstraction names where the program
runs, else the one jac.toml names. A name that is not listed ends the
program with status 1, saying which are."""
def:pub bound(abstraction: str, offers: Callable[[], Offers] | None = None) -> any {
    if abstraction in _made {
        return _made[abstraction];
    }
    if offers is None {
        raise RuntimeError(f"this program was built with no plugin for `{abstraction}`");
    }
    o = offers();
    want = o.named;
    for name in o.variables {
        picked = os.environ.get(name, "");
        if picked == "" {
            continue;
        }
        if picked not in o.listed {
            sys.stderr.write(
                f"{name}={picked}: this program was not built with a plugin '{picked}' for `{abstraction}`. jac.toml lists: {', '.join(o.listed)}\n",
            );
            sys.exit(1);
        }
        want = picked;
        break;
    }
    made = o.makers[o.listed.index(want)]();
    _made[abstraction] = made;
    return made;
}

"""`x`, a plugin made with jac.toml's settings, with each setting the place
it runs gives: `<variable>_<FIELD>` for each of `variables`, the most
particular winning, read as the field's type. A str is taken as it is
written, a `Secret` becomes the variable itself, and any other type is read
as JSON. A field its class sets in `postinit` is no setting."""
def:pub settle[T](x: T, variables: list[str]) -> T {
    comptime for f in fields(T) {
        comptime if not f.postinit {
            got = given(variables, f.name);
            if got is not None {
                comptime if f.type == Secret {
                    set_field(x, f.name, Secret(variable=got[0]));
                } elif kind(f.type) == Kind.STR {
                    set_field(x, f.name, got[1]);
                } else {
                    try {
                        set_field(x, f.name, decode[f.type](json.loads(got[1])));
                    } except Exception as e {
                        unfit(got, f.name, e);
                    }
                }
            }
        }
    }
    return x;
}

"""What the place a program runs gives the setting `field`: the variable that
gives it and its text, the most particular of `variables` winning; None where
none gives it."""
def given(variables: list[str], field: str) -> tuple[str, str] | None {
    for prefix in variables {
        name = prefix + "_" + field.upper();
        raw = os.environ.get(name, None);
        if raw is not None {
            return (name, raw);
        }
    }
    return None;
}

"""End the program over a setting's value that is not of its type: said with
its variable, and status 1."""
def unfit(got: tuple[str, str], field: str, why: Exception) {
    sys.stderr.write(f"{got[0]}={got[1]}: not a value of the setting `{field}`: {why}\n");
    sys.exit(1);
}
