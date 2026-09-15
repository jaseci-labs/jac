import os;
import sys;
import from pathlib { Path }

def get_jir_cache_dir -> Path {
    if sys.platform == "win32" {
        base = Path(
            os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))
        );
        return base / "jac" / "cache" / "jir";
    } elif sys.platform == "darwin" {
        return Path.home() / "Library" / "Caches" / "jac" / "jir";
    } else {
        xdg = os.environ.get("XDG_CACHE_HOME");
        base = Path(xdg) if xdg else (Path.home() / ".cache");
        return base / "jac" / "jir";
    }
}

def get_app_cache_dir -> Path {
    return get_jir_cache_dir().parent / "apps";
}
