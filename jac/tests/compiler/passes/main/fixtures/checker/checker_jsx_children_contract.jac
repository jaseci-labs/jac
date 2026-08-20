"""Children are part of the component contract -- W1053.

The codegen destructures declared parameter names out of `props` with no rest
element, so children handed to a component that declares none are dropped.
Zero-parameter components and `JsxPage`/`JsxLayout` ones are checked too.

A component element with children parses into three `JsxElement` nodes --
opening tag, closing tag, complete element -- and only the last is a call site;
validating a tag node would report every required prop as missing, which is what
`Required` guards."""

obj TypedProps {
    has title: str;
}

def Titled(title: str = "T") -> JsxElement {
    return <div>{title}</div>;
}

def WithChildren(title: str = "T", children: any = None) -> JsxElement {
    return <div>{title}{children}</div>;
}

def ZeroParam -> JsxElement {
    return <div>zero</div>;
}

def Required(title: str) -> JsxElement {
    return <div>{title}</div>;
}

def TitledPage(title: str = "T") -> JsxPage {
    return <div>{title}</div>;
}

def TypedBag(props: TypedProps) -> JsxElement {
    return <div>{props.title}</div>;
}

glob
     # W1053: `Titled` declares no `children`.
     a = <Titled title="ok">hello</Titled>,
     # W1053: an element child is dropped just the same.
     b = <Titled title="ok">
         <ZeroParam/>
     </Titled>,
     # OK: `WithChildren` declares them.
     c = <WithChildren title="ok">hello</WithChildren>,
     # OK: no children passed.
     d = <Titled title="ok"/>,
     # W1053: a zero-parameter component never reads its props.
     e = <ZeroParam>hello</ZeroParam>,
     # E1101: zero-parameter components are not exempt from prop checks.
     f = <ZeroParam bogus="x"/>,
     # OK: a lone `props` receives children as `props.children`.
     g = <TypedBag title="ok">hello</TypedBag>,
     # OK: whitespace and comments are not children.
     h = <Titled title="ok">
         {#* not a child *#}
     </Titled>,
     # W1053: a `-> JsxPage` route component drops them too.
     i = <TitledPage title="ok">hello</TitledPage>,
     # W1053, and no E1102 for the `title` this plainly passes.
     j = <Required title="ok">hello</Required>;
