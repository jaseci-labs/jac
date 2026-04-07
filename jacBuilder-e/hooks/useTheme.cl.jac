"""Theme hook — manages light/dark/system theme with localStorage persistence and cross-instance sync."""
import from react { useEffect, useRef }

glob _THEME_KEY: str = "jac_ide_theme";
glob _THEME_EVENT: str = "jac-theme-change";
glob _DEFAULT_THEME: str = "dark";

def _getStoredTheme() -> str {
    stored = localStorage.getItem(_THEME_KEY);
    if stored and (stored == "light" or stored == "dark" or stored == "system") {
        return stored;
    }
    return _DEFAULT_THEME;
}

def _resolveTheme(theme: str) -> str {
    if theme == "system" {
        mq = window.matchMedia("(prefers-color-scheme: dark)");
        return ("dark" if mq.matches else "light");
    }
    return theme;
}

def _applyThemeToDOM(resolved: str) -> None {
    cl = document.documentElement.classList;
    if resolved == "dark" {
        cl.remove("light");
        cl.add("dark");
    } else {
        cl.remove("dark");
        cl.add("light");
    }
}

def:pub useTheme() -> Any {
    has theme: str = _getStoredTheme();
    has resolvedTheme: str = _resolveTheme(_getStoredTheme());

    mountedRef = useRef(False);

    useEffect(lambda -> None {
        _applyThemeToDOM(_resolveTheme(theme));
        mountedRef.current = True;
    }, []);

    useEffect(lambda -> None {
        if not mountedRef.current {
            return;
        }
        r = _resolveTheme(theme);
        resolvedTheme = r;
        _applyThemeToDOM(r);
        localStorage.setItem(_THEME_KEY, theme);
        evt = Reflect.construct(CustomEvent, [_THEME_EVENT, {"detail": {"theme": theme}}]);
        window.dispatchEvent(evt);
    }, [theme]);

    useEffect(lambda -> None {
        handler = lambda(e: Any) -> None {
            incoming = e.detail.theme;
            if incoming != theme {
                theme = incoming;
                r = _resolveTheme(incoming);
                resolvedTheme = r;
                _applyThemeToDOM(r);
            }
        };
        window.addEventListener(_THEME_EVENT, handler);
        return lambda -> None {
            window.removeEventListener(_THEME_EVENT, handler);
        };
    }, [theme]);

    useEffect(lambda -> None {
        if theme != "system" {
            return lambda -> None {};
        }
        mq = window.matchMedia("(prefers-color-scheme: dark)");
        mediaHandler = lambda(_: Any) -> None {
            r = _resolveTheme("system");
            resolvedTheme = r;
            _applyThemeToDOM(r);
        };
        mq.addEventListener("change", mediaHandler);
        return lambda -> None {
            mq.removeEventListener("change", mediaHandler);
        };
    }, [theme]);

    return {"theme": theme, "resolvedTheme": resolvedTheme, "setTheme": setTheme};
}
