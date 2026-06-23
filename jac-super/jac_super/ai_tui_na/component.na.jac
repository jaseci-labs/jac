"""Component base objects for the pi-tui-inspired component spine.

Component.render(width) -> list[str]: one string per terminal row (ANSI SGR
codes allowed; no cursor-positioning sequences inside).

Container.render concatenates children vertically.

Phase 6: SelectList command palette via overlay.na.jac.
"""

obj Component {
    has _dirty: bool = True;

    def render(width: int) -> list[str] {
        return [];
    }

    def handle_input(data: str) -> bool {
        return False;
    }

    def invalidate {
        self._dirty = True;
    }
}

obj Container {
    has children: list[Component] = [];

    def add_child(child: Component) {
        self.children.append(child);
    }

    def clear_children {
        self.children = [];
    }

    def invalidate {
        i: int = 0;
        n = len(self.children);
        while i < n {
            self.children[i].invalidate();
            i = i + 1;
        }
    }

    def render(width: int) -> list[str] {
        lines: list[str] = [];
        i: int = 0;
        n = len(self.children);
        while i < n {
            child_lines = self.children[i].render(width);
            j: int = 0;
            m = len(child_lines);
            while j < m {
                lines.append(child_lines[j]);
                j = j + 1;
            }
            i = i + 1;
        }
        return lines;
    }
}
