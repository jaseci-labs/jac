"""Keyboard shortcut hook — replaces @mantine/hooks useHotkeys."""
cl import from "react" { useEffect }

cl {
    def:pub useHotkeys(shortcuts: list) -> None {
        useEffect(lambda {
            def handleKeyDown(e: Any) -> None {
                tag = "";
                if e.target {
                    tag = (e.target.tagName or "").toUpperCase();
                }
                isEditable = tag == "INPUT" or tag == "TEXTAREA" or tag == "SELECT" or (e.target and e.target.isContentEditable);
                for item in shortcuts {
                    combo = item[0];
                    handler = item[1];
                    parts = combo.toLowerCase().split("+");
                    needCtrl = parts.includes("mod") or parts.includes("ctrl");
                    needShift = parts.includes("shift");
                    needAlt = parts.includes("alt");
                    key = parts[parts.length - 1];

                    if isEditable and not needCtrl and not needAlt {
                        continue;
                    }

                    ctrlOk = True;
                    if needCtrl {
                        ctrlOk = e.ctrlKey or e.metaKey;
                    }
                    shiftOk = True;
                    if needShift {
                        shiftOk = e.shiftKey;
                    }
                    altOk = True;
                    if needAlt {
                        altOk = e.altKey;
                    }

                    keyMatch = e.key.toLowerCase() == key;
                    if keyMatch and ctrlOk and shiftOk and altOk {
                        e.preventDefault();
                        e.stopPropagation();
                        handlerFn = handler;
                        handlerFn.call(None, e);
                    }
                }
            }

            kd = handleKeyDown;
            document.addEventListener("keydown", kd);
            return lambda {
                document.removeEventListener("keydown", kd);
            };
        }, [shortcuts]);
    }
}
