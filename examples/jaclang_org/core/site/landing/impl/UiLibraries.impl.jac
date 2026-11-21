impl UiLibraries -> JsxElement {
    return <section className="mx-auto max-w-6xl px-6 py-24">
        <h2 className="text-3xl font-semibold tracking-tight">One component, three UI libraries</h2>
        <p className="mt-3 max-w-3xl text-muted-foreground">
            These panels are one Jac component, core/demo/Playground.jac, with no library named in it.
            The language says what state, derived values and effects mean, and a space says which library
            to use. Try the buttons: each panel is live, and each asks the same Jac function on the server.
        </p>
        <div className="mt-8 grid gap-4 lg:grid-cols-3">
            <div className="flex flex-col gap-2">
                <div className="font-medium">React <span
                    className="text-sm text-muted-foreground"
                >re-renders; this site runs on it</span></div>
                <div className="rounded-xl bg-[#0b0b0b] p-2 min-h-[460px]">
                    <Playground lib="React" />
                </div>
            </div>
            {[
                <div key={f["name"]} className="flex flex-col gap-2">
                    <div className="font-medium">{f["name"]} <span
                        className="text-sm text-muted-foreground"
                    >{f["note"]}</span></div>
                    <iframe
                        title={f["name"]}
                        src={f["src"]}
                        className="min-h-[460px] w-full rounded-xl border-0 bg-[#0b0b0b]"
                    />
                </div>
                for f in FRAMES
            ]}
        </div>
        <p className="mt-6 text-sm text-muted-foreground">
            React Native is the phone in the section above: the real app, on the same language rules.
        </p>
    </section>;
}
