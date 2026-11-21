"""What every plugin may use, whatever abstraction it fills: the program it
runs in (`Host`), a setting that is never written down (`Secret`), and what
it raises for data it can't start with (`DataError`).

A plugin's modules import the contract of the abstraction it fills
(`store.contract`), this one, the libraries its own jac.toml declares and the
standard library, and nothing else of jac's. What it needs of the program
that runs it, it is given: its `open` is handed the program as a `Host`,
and asks it.

A contract declares, and reaches nothing: no file, no variable of the
environment. So it is the same on every host a program's types are compiled
for, a browser's among them."""

"""A setting that is never written down: an API's key, a database's password.
A plugin declares the field with the variable its service's users already
set (`has key: Secret = Secret(variable="ANTHROPIC_API_KEY");`), and
`JAC_<ABSTRACTION>_<FIELD>` names another where the program runs. It names
the variable, and holds nothing of what the variable is: the plugin asks its
host for that (`Host.secret`)."""
obj Secret {
    has variable: str = "";
}

"""The program a plugin runs in, as the plugin sees it: what its `open` is
given, before anything else is asked of it. An abstraction whose plugins
need more of the program has a host of its own, which is one of these
(`auth.contract`'s AuthHost, `jobs.contract`'s JobsHost)."""
obj Host {
    """Where the program keeps what it keeps beside itself: its app's data
    directory. A plugin that keeps a file keeps it here unless its settings
    say where."""
    def data_dir -> str abst;

    """Tell whoever starts the program what was done to their data as it was
    opened, a sentence without its subject ("upgraded accounts.db from
    layout 1 to 2; the file as it was is kept as accounts.db.layout1"): the
    program says it as it starts."""
    def upgraded(what: str) abst;

    """What the place the program runs gives the secret `s`: what its
    variable holds there, or "" where it gives none."""
    def secret(s: Secret) -> str abst;
}

"""Data an app kept that it can't start with: the file at `path` ("" for a
plugin that keeps no file of its own to name), and what is wrong with it, as
what follows the file's name in a sentence ("is laid out as a newer jac
writes it"). It is the state of someone's data, not a fault of the program:
what starts an app says it, in words, and stops."""
obj DataError(Exception) {
    has path: str,
        problem: str;

    def __str__ -> str {
        return f"{self.path} {self.problem}" if self.path != "" else self.problem;
    }
}
