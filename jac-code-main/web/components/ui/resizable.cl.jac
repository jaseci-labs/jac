cl import from "react-resizable-panels" { PanelGroup, Panel, PanelResizeHandle }
cl import from ...lib.utils { cn }

cl {
    def:pub ResizablePanelGroup(props: Any) -> JsxElement {
        return <PanelGroup
            {...props}
            data-slot="resizable-panel-group"
            className={cn("cn-resizable-panel-group flex h-full w-full aria-[orientation=vertical]:flex-col", props.className)}
        />;
    }

    def:pub ResizablePanel(props: Any) -> JsxElement {
        return <Panel data-slot="resizable-panel" {...props} />;
    }

    def:pub ResizableHandle(props: Any) -> JsxElement {
        withHandle = props.withHandle or False;
        return <PanelResizeHandle
            {...props}
            data-slot="resizable-handle"
            className={cn("cn-resizable-handle bg-border focus-visible:ring-ring ring-offset-background relative flex w-px items-center justify-center after:absolute after:inset-y-0 after:left-1/2 after:w-1 after:-translate-x-1/2 focus-visible:ring-1 focus-visible:outline-hidden aria-[orientation=horizontal]:h-px aria-[orientation=horizontal]:w-full aria-[orientation=horizontal]:after:left-0 aria-[orientation=horizontal]:after:h-1 aria-[orientation=horizontal]:after:w-full aria-[orientation=horizontal]:after:translate-x-0 aria-[orientation=horizontal]:after:-translate-y-1/2", props.className)}
        >
            {withHandle and <div className="bg-border h-6 w-1 rounded-lg z-10 flex shrink-0" />}
        </PanelResizeHandle>;
    }
}
