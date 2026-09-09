import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }

test "Jac release updates the site pin and reports the manifest" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        (base / "scripts").mkdir();
        site = base / "jac/examples/jaclang_org/jac.toml";
        site.parent.mkdir(parents=True);
        original = "# Keep workspace settings\n[project]\nname = 'jaclang_org'\njac-version = '==0.37.3'\n\n[apps.mobile]\nkind = 'mobile'\n";
        site.write_text(original);
        (base / "jac.toml").write_text("[project]\nversion = '0.37.5'\n");
        args = argparse.Namespace(jaclang="patch", dry_run=True);
        with patch(main.__module__ + ".__file__", str(base / "scripts/release.jac")), patch(
            main.__module__ + ".parse_args", return_value=args
        ), patch(main.__module__ + ".update_release_notes"), patch(
            main.__module__ + ".set_output"
        ) as output {
            main();
            assert site.read_text() == original;
            assert read_version(base / "jac.toml") == "0.37.5";
            output.assert_not_called();
            args.dry_run = False;
            main();
            assert read_version(base / "jac.toml") == "0.37.6";
            data = tomlkit.loads(site.read_text());
            assert data["project"]["jac-version"] == "==0.37.6";
            assert data["apps"]["mobile"]["kind"] == "mobile";
            assert "# Keep workspace settings" in site.read_text();
            files = [
                c.args[1]
                for c in output.call_args_list
                if c.args[0] == "modified_files"
            ][0];
            assert "jac/examples/jaclang_org/jac.toml" in files.split();
        }
    }
}
