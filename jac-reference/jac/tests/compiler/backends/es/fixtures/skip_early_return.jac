def:pub SkipTest() -> JsxElement {
    has value: str = "";

    def handle_submit() {
        if len(value) == 0 {
            skip;
        }
        value = "submitted";
    }

    return <div>
        <button onClick={lambda { handle_submit(); }}>{"Submit"}</button>
        <p>{value}</p>
    </div>;
}
