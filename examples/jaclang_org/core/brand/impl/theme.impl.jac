impl useTheme -> Theme {
    has dark: bool = __getLocalStorage("jac-theme") != "light",
        heard: Ref[any] = Ref(None);
    def changed(value: bool) {
        dark = value;
    }
    can with entry {
        listeners.append(changed);
        heard.current = changed;
    }
    can with exit {
        listeners = [listener for listener in listeners if listener != heard.current];
    }
    def toggle {
        value = not dark;
        __setLocalStorage("jac-theme", "dark" if value else "light");
        for listener in listeners {
            listener(value);
        }
    }
    return Theme(dark=dark, colors=dark_palette() if dark else light_palette(), toggle=toggle);
}
