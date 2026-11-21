---
description: The native argparse, getopt, configparser and getpass modules, as CPython's - parsing a command line, reading INI configuration, and asking for a password.
keywords: argparse, argparse.ArgumentParser, ArgumentParser, argparse.Namespace, argparse.Action, argparse.FileType, argparse.BooleanOptionalAction, argparse.ArgumentError, argparse.ArgumentTypeError, argparse.HelpFormatter, argparse.RawTextHelpFormatter, argparse.ArgumentDefaultsHelpFormatter, add_argument, parse_args, add_subparsers, add_mutually_exclusive_group, getopt, getopt.getopt, getopt.gnu_getopt, getopt.GetoptError, configparser, configparser.ConfigParser, ConfigParser, configparser.RawConfigParser, configparser.SectionProxy, configparser.BasicInterpolation, configparser.ExtendedInterpolation, getpass, getpass.getpass, getpass.getuser
---
# argparse, getopt, configparser and getpass

`argparse` parses a command line as CPython's does, and its help, usage and error messages are
CPython's byte for byte. `getopt` is the C-style parser. `configparser` reads and writes INI
files, with CPython's interpolation, converters and errors. `getpass` reads a password without
echoing it and tells the user's login name. All four are native (see
[The library](index.md), `jac docs library`).

```jac
import argparse;
import configparser;
import getopt;

with entry {
    p = argparse.ArgumentParser(prog="tool", description="Copy files.");
    p.add_argument("src");
    p.add_argument("-n", "--count", type=int, default=1, help="how many times");
    p.add_argument("-v", "--verbose", action="store_true");
    p.add_argument("--mode", choices=["fast", "safe"], default="safe");
    args = p.parse_args(["in.txt", "-n", "3", "--verbose"]);
    print(args.src, args.count, args.verbose, args.mode);
    print(args);
    print(p.format_usage(), end="");
    (opts, rest) = getopt.getopt(["-a", "-b", "x", "file"], "ab:");
    print(opts, rest);
    cfg = configparser.ConfigParser();
    cfg.read_string(
        "[server]\nhost = example.org\nport = 8080\n[paths]\nroot = /srv\nlogs = %(root)s/logs\n"
    );
    print(
        cfg.sections(),
        cfg["server"]["host"],
        cfg.getint("server", "port"),
        cfg.get("paths", "logs"),
    );
}
```

```output
in.txt 3 True safe
Namespace(src='in.txt', count=3, verbose=True, mode='safe')
usage: tool [-h] [-n COUNT] [-v] [--mode {fast,safe}] src
[('-a', ''), ('-b', 'x')] ['file']
['server', 'paths'] example.org 8080 /srv/logs
```

## argparse

Every part of CPython's `argparse` is there: positional and optional arguments, `nargs`
(`?`, `*`, `+`, `argparse.REMAINDER`, a count), the actions (`store`, `store_const`,
`store_true`, `append`, `append_const`, `extend`, `count`, `help`, `version`,
`BooleanOptionalAction`, and an `Action` class of a program's own), `type` and `choices`,
`required`, `default` and `argparse.SUPPRESS`, `dest` and `metavar`, sub-commands
(`add_subparsers`), argument groups, mutually exclusive groups, `parse_known_args`,
`parse_intermixed_args`, prefix matching of long options, `fromfile_prefix_chars`, the help
formatters, `FileType`, and Python 3.14's `suggest_on_error` and `color`.

`parse_args` returns a `Namespace` whose attributes are found by name as the program runs, so
`args.count` is an `any`: give it a type where it is used (`n: int = args.count;`). A wrong
command line prints the usage and the error to standard error and raises `SystemExit` with
status 2, as CPython does:

```jac
import argparse;

with entry {
    p = argparse.ArgumentParser(prog="tool");
    p.add_argument("--count", type=int, default=1);
    try {
        p.parse_args(["--count", "many"]);
    } except SystemExit as e {
        print("exit status", e.code);
    }
    print(p.format_help(), end="");
}
```

```output
exit status 2
usage: tool [-h] [--count COUNT]

options:
  -h, --help     show this help message and exit
  --count COUNT
```

On standard error, that program writes CPython's two lines:

```text
usage: tool [-h] [--count COUNT]
tool: error: argument --count: invalid int value: 'many'
```

## getopt

`getopt(args, shortopts, longopts=[])` and `gnu_getopt` return the options as `(name, value)`
pairs and the arguments left; an unknown option raises `GetoptError` with CPython's message
(`option -z not recognized`).

## configparser

`ConfigParser`, `RawConfigParser` and `SectionProxy`, with `read`, `read_file`,
`read_string`, `read_dict`, `write`, the typed getters (`getint`, `getfloat`, `getboolean`, and
converters of a program's own), `BasicInterpolation` (`%(name)s`) and `ExtendedInterpolation`
(`${section:name}`), the `DEFAULT` section, Python 3.13's `allow_unnamed_section`, and every
error class (`NoSectionError`, `DuplicateOptionError`, `InterpolationMissingOptionError`, ...)
with CPython's messages.

## getpass

`getpass(prompt="Password: ", stream=None, echo_char=None)` reads a line from the terminal with
echo turned off (Python 3.14's `echo_char` shows a character for each one typed), and
`getuser()` returns the login name from `LOGNAME`, `USER`, `LNAME` or `USERNAME`, else from the
password database. The terminal is the process's controlling one, `/dev/tty`; without one the
password is read from standard input with its echo off, and where that is not a terminal
either, as it comes, after CPython's warning line on the stream. The `GetPassWarning` CPython
issues then is not issued, as no module issues warnings.
