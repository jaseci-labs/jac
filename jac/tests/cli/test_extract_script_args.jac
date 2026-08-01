"""Unit tests for REMAINDER argv splitting before argparse runs."""

import from jaclang.cli.command { ArgKind }
import from jaclang.cli.dispatch { split_remainder_argv }
import from jaclang.cli.manifest { ArgMeta, CommandMeta }


def _run_meta(args: list[ArgMeta]) -> CommandMeta {
    return CommandMeta(
        name="probe",
        help="probe",
        group="general",
        tier="",
        hidden=True,
        handler_module="",
        handler_name="",
        args=args
    );
}

test "split_remainder_argv returns None without a REMAINDER arg" {
    meta = _run_meta(
        [ArgMeta(name="filename", kind=ArgKind.POSITIONAL, default="", help="x")]
    );
    assert split_remainder_argv(["run", "app.jac", "arg1"], meta) is None;
}

test "split_remainder_argv splits script args after the positional" {
    meta = _run_meta(
        [
            ArgMeta(name="filename", kind=ArgKind.POSITIONAL, default="", help="x"),
            ArgMeta(name="args", kind=ArgKind.REMAINDER, help="script args"),

        ]
    );
    (trimmed, script_args) = split_remainder_argv(
        ["run", "app.jac", "one", "two"], meta
    );
    assert trimmed == ["run", "app.jac"];
    assert script_args == ["one", "two"];
}

test "split_remainder_argv honors -- terminator" {
    meta = _run_meta(
        [
            ArgMeta(name="filename", kind=ArgKind.POSITIONAL, default="", help="x"),
            ArgMeta(name="args", kind=ArgKind.REMAINDER, help="script args"),

        ]
    );
    (trimmed, script_args) = split_remainder_argv(
        ["run", "app.jac", "--", "--weird", "tail"], meta
    );
    assert trimmed == ["run", "app.jac"];
    assert script_args == ["--weird", "tail"];
}

test "split_remainder_argv passes flags after the positional to script args" {
    meta = _run_meta(
        [
            ArgMeta(name="filename", kind=ArgKind.POSITIONAL, default="", help="x"),
            ArgMeta(name="profile", typ="str", default="", help="profile"),
            ArgMeta(name="args", kind=ArgKind.REMAINDER, help="script args"),

        ]
    );
    (trimmed, script_args) = split_remainder_argv(
        ["run", "app.jac", "--profile", "prod", "tail"], meta
    );
    assert trimmed == ["run", "app.jac"];
    assert script_args == ["--profile", "prod", "tail"];
}

test "split_remainder_argv passes attached flags after the positional to script args" {
    meta = _run_meta(
        [
            ArgMeta(name="filename", kind=ArgKind.POSITIONAL, default="", help="x"),
            ArgMeta(name="profile", typ="str", default="", help="profile"),
            ArgMeta(name="args", kind=ArgKind.REMAINDER, help="script args"),

        ]
    );
    (trimmed, script_args) = split_remainder_argv(
        ["run", "app.jac", "--profile=prod", "tail"], meta
    );
    assert trimmed == ["run", "app.jac"];
    assert script_args == ["--profile=prod", "tail"];
}

test "split_remainder_argv consumes value flags before the positional" {
    meta = _run_meta(
        [
            ArgMeta(name="filename", kind=ArgKind.POSITIONAL, default="", help="x"),
            ArgMeta(name="profile", typ="str", default="", help="profile"),
            ArgMeta(name="args", kind=ArgKind.REMAINDER, help="script args"),

        ]
    );
    (trimmed, script_args) = split_remainder_argv(
        ["run", "--profile", "prod", "app.jac", "tail"], meta
    );
    assert trimmed == ["run", "--profile", "prod", "app.jac"];
    assert script_args == ["tail"];
}

test "split_remainder_argv consumes attached flags before the positional" {
    meta = _run_meta(
        [
            ArgMeta(name="filename", kind=ArgKind.POSITIONAL, default="", help="x"),
            ArgMeta(name="profile", typ="str", default="", help="profile"),
            ArgMeta(name="args", kind=ArgKind.REMAINDER, help="script args"),

        ]
    );
    (trimmed, script_args) = split_remainder_argv(
        ["run", "--profile=prod", "app.jac", "tail"], meta
    );
    assert trimmed == ["run", "--profile=prod", "app.jac"];
    assert script_args == ["tail"];
}

test "split_remainder_argv consumes short value flags before the positional" {
    meta = _run_meta(
        [
            ArgMeta(name="filename", kind=ArgKind.POSITIONAL, default="", help="x"),
            ArgMeta(name="profile", typ="str", default="", help="profile", short="p"),
            ArgMeta(name="args", kind=ArgKind.REMAINDER, help="script args"),

        ]
    );
    (trimmed, script_args) = split_remainder_argv(
        ["run", "-p", "prod", "app.jac", "tail"], meta
    );
    assert trimmed == ["run", "-p", "prod", "app.jac"];
    assert script_args == ["tail"];
}

test "split_remainder_argv supports multiple positionals" {
    meta = _run_meta(
        [
            ArgMeta(name="tool", kind=ArgKind.POSITIONAL, help="tool"),
            ArgMeta(name="filename", kind=ArgKind.POSITIONAL, default="", help="x"),
            ArgMeta(name="args", kind=ArgKind.REMAINDER, help="script args"),

        ]
    );
    (trimmed, script_args) = split_remainder_argv(
        ["tool", "sub", "file.jac", "tail"], meta
    );
    assert trimmed == ["tool", "sub", "file.jac"];
    assert script_args == ["tail"];
}
