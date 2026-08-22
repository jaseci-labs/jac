"""Regression test for #7464: bool Args with default=None parse tri-state,
so handlers can tell an explicit `--no-X` apart from the flag not being given."""

import argparse;
import from jaclang.cli.manifest { ArgMeta }
import from jaclang.cli.manifest_parse { add_argument }


test "bool Arg with default=None: unspecified None, --X True, --no-X False" {
    parser = argparse.ArgumentParser();
    add_argument(parser, ArgMeta(name="npm", typ="bool", `default=None, help="x"));
    assert vars(parser.parse_args([]))["npm"] is None;
    assert vars(parser.parse_args(["--npm"]))["npm"] is True;
    assert vars(parser.parse_args(["--no-npm"]))["npm"] is False;
}

test "bool Arg with explicit default keeps two-state behavior" {
    parser = argparse.ArgumentParser();
    add_argument(parser, ArgMeta(name="scale", typ="bool", `default=False, help="x"));
    assert vars(parser.parse_args([]))["scale"] is False;
    assert vars(parser.parse_args(["--scale"]))["scale"] is True;
    assert vars(parser.parse_args(["--no-scale"]))["scale"] is False;

    parser2 = argparse.ArgumentParser();
    add_argument(parser2, ArgMeta(name="loud", typ="bool", `default=True, help="x"));
    assert vars(parser2.parse_args([]))["loud"] is True;
    assert vars(parser2.parse_args(["--no-loud"]))["loud"] is False;
}

test "bool Arg named no-* gets no negated twin" {
    parser = argparse.ArgumentParser();
    add_argument(parser, ArgMeta(name="no-save", typ="bool", `default=False, help="x"));
    assert vars(parser.parse_args(["--no-save"]))["no_save"] is True;
    assert vars(parser.parse_args([]))["no_save"] is False;
    option_strings = [s for a in parser._actions for s in a.option_strings];
    assert "--no-no-save" not in option_strings;
}
