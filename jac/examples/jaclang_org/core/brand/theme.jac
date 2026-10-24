import from "@jac/runtime" { __getLocalStorage, __setLocalStorage }

glob listeners: list[Callable[[bool], None]] = [];

obj Theme {
    has dark: bool,
        colors: Colors,
        toggle: Callable[[], None];
}

def:pub useTheme -> Theme;
