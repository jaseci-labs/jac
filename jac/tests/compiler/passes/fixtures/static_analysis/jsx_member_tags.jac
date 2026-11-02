"""A dotted JSX tag is a member expression: its later parts are attributes."""

obj Dialog {
    static def Provider(children: any = None) -> JsxElement {
        <section>{children}</section>
    }

    static def Trigger(label: str) -> JsxElement {
        <button type="button">{label}</button>
    }
}

glob panels = Dialog;

def:pub Uppercase(label: str) -> JsxElement {
    <Dialog.Provider>
        <Dialog.Trigger label={label}/>
    </Dialog.Provider>
}

def:pub Lowercase(label: str) -> JsxElement {
    <panels.Provider>
        <panels.Trigger label={label}/>
    </panels.Provider>
}

def:pub Unknown -> JsxElement {
    <Missing.Part/>
}
