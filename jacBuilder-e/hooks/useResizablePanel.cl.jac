"""Drag-to-resize panel hook."""

import from react { useEffect, useRef }

"""Hook for managing a resizable panel with drag-to-resize behavior."""
def:pub useResizablePanel() -> Any {
    has previewWidth: int = Math.floor(window.innerWidth * 0.45);
    has isDragging: bool = False;

    isDraggingRef = useRef(False);
    previewWidthRef = useRef(previewWidth);
    rafRef = useRef(None);
    lastClientXRef = useRef(0);

    def clampWidth(width: int) -> int {
        maxWidth = Math.floor(window.innerWidth * 0.6);
        if width < 200 {
            return 200;
        }
        if width > maxWidth {
            return maxWidth;
        }
        return width;
    }

    def applyWidthFromClientX(clientX: int) -> None {
        # Preview panel is docked to the right; width should follow cursor position directly.
        targetWidth = window.innerWidth - clientX;
        previewWidth = clampWidth(targetWidth);
    }

    useEffect(lambda {
        isDraggingRef.current = isDragging;
    }, [isDragging]);

    useEffect(lambda {
        previewWidthRef.current = previewWidth;
    }, [previewWidth]);

    useEffect(lambda {
        def handleMouseMove(e: Any) -> None {
            if not isDraggingRef.current { return; }
            lastClientXRef.current = e.clientX;
            if rafRef.current { return; }

            rafRef.current = requestAnimationFrame(lambda {
                rafRef.current = None;
                applyWidthFromClientX(lastClientXRef.current);
            });
        }

        def handleMouseUp(_: Any) -> None {
            if not isDraggingRef.current { return; }
            isDragging = False;
            isDraggingRef.current = False;
            document.body.style.cursor = "";
            document.body.style.userSelect = "";
        }

        document.addEventListener("mousemove", handleMouseMove);
        document.addEventListener("mouseup", handleMouseUp);

        return lambda -> None {
            document.removeEventListener("mousemove", handleMouseMove);
            document.removeEventListener("mouseup", handleMouseUp);
            if rafRef.current {
                cancelAnimationFrame(rafRef.current);
                rafRef.current = None;
            }
        };
    }, []);

    useEffect(lambda {
        def handleWindowResize(_: Any) -> None {
            previewWidth = clampWidth(previewWidthRef.current);
        }
        window.addEventListener("resize", handleWindowResize);
        return lambda -> None {
            window.removeEventListener("resize", handleWindowResize);
        };
    }, []);

    def startDrag(e: Any) -> None {
        e.preventDefault();
        e.stopPropagation();
        isDragging = True;
        isDraggingRef.current = True;
        document.body.style.cursor = "col-resize";
        document.body.style.userSelect = "none";
        applyWidthFromClientX(e.clientX);
    }

    return {
        "previewWidth": previewWidth,
        "isDragging": isDragging,
        "startDrag": startDrag
    };
}
