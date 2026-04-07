"""Click outside hook — replaces @mantine/hooks useClickOutside."""
cl import from "react" { useEffect, useRef }

cl {
    def:pub useClickOutside(handler: Any) -> Any {
        ref = useRef(None);

        useEffect(lambda {
            def handleClick(e: Any) -> None {
                if ref.current and not ref.current.contains(e.target) {
                    fn = handler;
                    fn.call(None, e);
                }
            }
            hc = handleClick;
            document.addEventListener("mousedown", hc);
            return lambda {
                document.removeEventListener("mousedown", hc);
            };
        }, [handler]);

        return ref;
    }
}
