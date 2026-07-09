"""Regression test for #6115: hyphenated bool Args used to leak a
phantom `X-dashed: True` namespace key via the auto `--no-X` companion."""

import argparse;
import from jaclang.cli.command { Arg }
import from jaclang.cli.registry { CommandRegistry }


test "hyphenated bool Arg: no phantom key, --no-X toggles through the dest" {
    registry = CommandRegistry();

    # Registry: hyphenated bool produces one underscored namespace key
    parser = argparse.ArgumentParser();
    registry._add_argument(
        parser, Arg.create("dry-run", typ=bool, default=False, help="x", short="")
    );
    d = vars(parser.parse_args([]));
    assert d.get("dry_run") is False;
    assert "dry-run" not in d , f"phantom 'dry-run' key leaked: {list(d.keys())}";

    # --dry-run sets it True; --no-dry-run toggles through the same dest
    assert vars(parser.parse_args(["--dry-run"]))["dry_run"] is True;
    parser2 = argparse.ArgumentParser();
    registry._add_argument(
        parser2, Arg.create("dry-run", typ=bool, default=True, help="x", short="")
    );
    assert vars(parser2.parse_args(["--no-dry-run"]))["dry_run"] is False;

    # Non-hyphenated unchanged
    parser3 = argparse.ArgumentParser();
    registry._add_argument(
        parser3, Arg.create("scale", typ=bool, default=False, help="x", short="")
    );
    assert vars(parser3.parse_args(["--scale"]))["scale"] is True;
}
