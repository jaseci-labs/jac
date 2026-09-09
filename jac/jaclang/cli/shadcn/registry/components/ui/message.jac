import from ...lib.utils { cn }

glob _messageExcludeKeys: list[str] = ["className", "align"];

def:pub MessageGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="message-group"
        className={cn("cn-message-group flex min-w-0 flex-col", props["className"])}
    />
}

def:pub Message(props: any) -> JsxElement {
    align = props["align"] or "start";
    restProps = {};
    for key in Object.keys(props) {
        if key not in _messageExcludeKeys {
            restProps[key] = props[key];
        }
    }
    <div
        {**restProps}
        data-slot="message"
        data-align={align}
        className={cn(
            "cn-message group/message relative flex w-full min-w-0 data-[align=end]:flex-row-reverse",
            props["className"]
        )}
    />
}

def:pub MessageAvatar(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="message-avatar"
        className={cn(
            "cn-message-avatar flex w-fit shrink-0 items-center justify-center self-end overflow-hidden rounded-full bg-muted",
            props["className"]
        )}
    />
}

def:pub MessageContent(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="message-content"
        className={cn(
            "cn-message-content flex w-full min-w-0 flex-col wrap-break-word",
            props["className"]
        )}
    />
}

def:pub MessageHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="message-header"
        className={cn(
            "cn-message-header flex max-w-full min-w-0 items-center", props["className"]
        )}
    />
}

def:pub MessageFooter(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="message-footer"
        className={cn(
            "cn-message-footer flex max-w-full min-w-0 items-center group-data-[align=end]/message:justify-end",
            props["className"]
        )}
    />
}
