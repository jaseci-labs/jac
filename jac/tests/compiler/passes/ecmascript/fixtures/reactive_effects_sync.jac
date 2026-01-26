"""Test fixture for synchronous reactive effects (non-async can with entry).

Note: useEffect import is auto-injected from @jac/runtime when `can with entry/exit` is used.
"""

cl {
    def:pub title_component() -> any {
        has title: str = "Default";

        # Sync mount effect - no IIFE wrapping needed
        can with entry {
            document.title = title;
        }

        return <div>{title}</div>;
    }
}
