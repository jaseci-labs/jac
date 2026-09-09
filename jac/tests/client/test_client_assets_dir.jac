"""The client assets directory: the app's own assets/ by default, or one
shared directory named by [client.assets] dir, served under /static/assets
and resolved from source with nested paths intact."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.client.config_loader { JacClientConfig }
import from jaclang.server.static_files { find_root_asset, find_static_candidate }


def _project(base: Path, assets_dir: str) {
    (base / "main.jac").write_text("def app -> str { return \"hi\"; }\n");
    section = f"[client.assets]\ndir = \"{assets_dir}\"\n" if assets_dir else "";
    (base / "jac.toml").write_text(
        "[project]\nname = \"assets-probe\"\nversion = \"0.0.1\"\nentry-point = \"main.jac\"\n\n"
            + section
    );
}


test "the assets directory defaults to the app base's assets" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _project(base, "");
        assert JacClientConfig(base).get_assets_dir() == base / "assets";
    }
}


test "a configured assets directory resolves against the project base" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _project(base, "core/site/assets");
        assert JacClientConfig(base).get_assets_dir()
            == base / "core" / "site" / "assets";
    }
}


test "static requests find shared assets from source, nested paths intact" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        _project(base, "core/site/assets");
        shared = base / "core" / "site" / "assets";
        (shared / "media").mkdir(parents=True);
        (shared / "logo.svg").write_text("<svg/>");
        (shared / "media" / "diagram.png").write_bytes(b"png");
        assert find_static_candidate(str(base), "assets/logo.svg")
            == shared / "logo.svg";
        assert (
            find_static_candidate(str(base), "assets/media/diagram.png")
            == shared / "media" / "diagram.png"
        );
        assert find_root_asset(str(base), "logo.svg") == shared / "logo.svg";
        assert find_static_candidate(str(base), "assets/missing.svg") is None;
    }
}
