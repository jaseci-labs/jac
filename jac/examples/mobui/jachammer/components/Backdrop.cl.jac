"""Full-screen tap-to-dismiss backdrop behind modal sheets."""

cl {
    import from "@jac/mobui" { Pressable }

    def:pub Backdrop(close: any) -> JsxElement {
        return <Pressable style={{position: "absolute", top: 0, left: 0, right: 0, bottom: 0}} onPress={close}/>;
    }
}
