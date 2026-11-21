import from "radix-ui" { Direction }

def:pub DirectionProvider(props: any) -> JsxElement {
    dirValue = props["direction"] or props["dir"];
    <Direction.DirectionProvider dir={dirValue}>
        {props["children"]}
    </Direction.DirectionProvider>
}

def:pub useDirection -> any {
    return Direction.useDirection();
}
