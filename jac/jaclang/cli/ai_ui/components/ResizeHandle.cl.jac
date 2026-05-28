"""A draggable gutter that reports the cumulative drag delta to its parent.

`vertical` sits between side-by-side panes and reports the horizontal delta (drag
left/right); otherwise it sits between stacked panes and reports the vertical
delta (drag up/down). The parent adds the delta to the pane size captured when
the drag began -- which is exactly the value its `onResize` closure holds -- so
the pane tracks the cursor.

The delta is measured from the pointer's position at mousedown (`clientX/Y -
start`), NOT per-event `movementX/Y`: the parent's `onResize` is the closure
captured at mousedown (the window listener keeps the same one for the whole
drag), so its pane-size value is frozen at the start value. Reporting a
cumulative delta against that frozen base tracks the cursor; reporting a
per-event delta would just re-add one frame's movement to the start each time,
pinning the pane near its origin.

Listeners are attached to `window` on mousedown and removed on mouseup, so a drag
keeps tracking even when the pointer moves faster than the 6px gutter.
"""

def:pub ResizeHandle(vertical: bool, onResize: any) -> JsxElement {
    def onDown(e: any) {
        e.preventDefault();
        startX = e.clientX;
        startY = e.clientY;
        def onMove(ev: any) {
            onResize((ev.clientX - startX) if vertical else (ev.clientY - startY));
        }
        def onUp(ev: any) {
            window.removeEventListener("mousemove", onMove);
            window.removeEventListener("mouseup", onUp);
            document.body.classList.remove("resizing");
        }
        # While dragging, suppress text selection / cursor flicker across the page.
        document.body.classList.add("resizing");
        window.addEventListener("mousemove", onMove);
        window.addEventListener("mouseup", onUp);
    }
    return
        <div
            className={"resize-handle " + ("v" if vertical else "h")}
            onMouseDown={onDown}
        />;
}
