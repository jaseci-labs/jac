import os;
import from contextlib { chdir }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.cli.browser_engine { _find_chrome }

def find_in(base: Path, playwright: str = "", chrome: str = "") -> str {
    def exists(path: Path) -> bool {
        path = path.absolute();
        return path.is_relative_to(base) and (path.is_file() or path.is_dir());
    }

    with patch.dict(
        os.environ,
        {"PLAYWRIGHT_BROWSERS_PATH": playwright, "JACBROWSER_CHROME": chrome}
    ), patch("shutil.which", return_value=None), patch.object(
        Path, "home", return_value=base / "home"
    ), patch.object(Path, "exists", autospec=True, side_effect=exists) {
        return _find_chrome();
    }
}

test "configured Playwright directory supplies Chromium and headless shell" {
    for rel in [
        "chromium-1198/chrome-linux/chrome",
        "chromium-1198/chrome-linux64/chrome",
        "chromium-1198/chrome-linux-arm64/chrome",
        "chromium-1198/chrome-mac/Chromium.app/Contents/MacOS/Chromium",
        "chromium-1198/chrome-mac-x64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing",
        "chromium-1198/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing",
        "chromium_headless_shell-1198/chrome-linux/headless_shell",
        "chromium_headless_shell-1198/chrome-mac/headless_shell",
        "chromium_headless_shell-1198/chrome-headless-shell-linux64/chrome-headless-shell",
        "chromium_headless_shell-1198/chrome-headless-shell-linux-arm64/chrome-headless-shell",
        "chromium_headless_shell-1198/chrome-headless-shell-mac-x64/chrome-headless-shell",
        "chromium_headless_shell-1198/chrome-headless-shell-mac-arm64/chrome-headless-shell"
    ] {
        with TemporaryDirectory() as directory {
            base = Path(directory);
            pw = base / "playwright";
            exe = pw / rel;
            exe.parent.mkdir(parents=True);
            exe.touch();
            assert find_in(base, str(pw)) == str(exe);
        }
    }
}

test "configured Playwright directory precedes default caches" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        pw = base / "playwright";
        exe = pw / "chromium-1198/chrome-linux/chrome";
        fallback = base / "home/.cache/ms-playwright/chromium-9999/chrome-linux/chrome";
        for path in [exe, fallback] {
            path.parent.mkdir(parents=True);
            path.touch();
        }
        assert find_in(base, str(pw)) == str(exe);
    }
}

test "explicit Chrome override precedes Playwright discovery" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        explicit = str(base / "explicit-chrome");
        assert find_in(base, str(base / "playwright"), explicit) == explicit;
    }
}

test "Chrome on PATH precedes Playwright discovery" {
    with patch.dict(
        os.environ, {"JACBROWSER_CHROME": "", "PLAYWRIGHT_BROWSERS_PATH": "/playwright"}
    ), patch("shutil.which", return_value="/bin/chromium") {
        assert _find_chrome() == "/bin/chromium";
    }
}

test "default Playwright caches remain discoverable" {
    for cache in [".cache/ms-playwright", "Library/Caches/ms-playwright"] {
        with TemporaryDirectory() as directory {
            base = Path(directory);
            exe = base / "home" / cache / "chromium-1198/chrome-linux/chrome";
            exe.parent.mkdir(parents=True);
            exe.touch();
            assert find_in(base) == str(exe);
            assert find_in(base, "0") == str(exe);
            assert find_in(base, str(base / "missing")) == str(exe);
            empty = base / "empty";
            empty.mkdir();
            assert find_in(base, str(empty)) == str(exe);
        }
    }
}

test "Playwright zero is not treated as a browser directory" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        exe = base / "0/chromium-1198/chrome-linux/chrome";
        exe.parent.mkdir(parents=True);
        exe.touch();
        with chdir(base) {
            try {
                find_in(base, "0");
            } except FileNotFoundError {
                return;
            }
        }
        assert False , "PLAYWRIGHT_BROWSERS_PATH=0 must not search a literal 0 directory";
    }
}

test "missing browser reports searched Playwright directories" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        pw = base / "playwright";
        try {
            find_in(base, str(pw));
        } except FileNotFoundError as error {
            message = str(error);
            assert str(pw) in message;
            assert str(base / "home/.cache/ms-playwright") in message;
            assert str(base / "home/Library/Caches/ms-playwright") in message;
            assert "JACBROWSER_CHROME" in message;
            return;
        }
        assert False , "expected missing-browser error";
    }
}

test "headless shell is discovered in a default Playwright cache" {
    for rel in [
        "chrome-linux/headless_shell",
        "chrome-headless-shell-linux64/chrome-headless-shell"
    ] {
        with TemporaryDirectory() as directory {
            base = Path(directory);
            exe = base / "home/.cache/ms-playwright/chromium_headless_shell-1198" / rel;
            exe.parent.mkdir(parents=True);
            exe.touch();
            assert find_in(base) == str(exe);
        }
    }
}

test "relative Playwright browser directory is discoverable" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        exe = base / "playwright/chromium-1198/chrome-linux/chrome";
        exe.parent.mkdir(parents=True);
        exe.touch();
        with chdir(base) {
            assert find_in(base, "playwright") == str(exe.relative_to(base));
        }
    }
}

test "full Chromium precedes headless shell in the same cache" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        pw = base / "playwright";
        full = pw / "chromium-1198/chrome-linux64/chrome";
        shell = pw
            / "chromium_headless_shell-9999/chrome-headless-shell-linux64/chrome-headless-shell";
        for exe in [full, shell] {
            exe.parent.mkdir(parents=True);
            exe.touch();
        }
        assert find_in(base, str(pw)) == str(full);
    }
}
