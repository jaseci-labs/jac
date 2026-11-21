impl page(*lost: str) -> JsxPage {
    return <NotFound /> if len(lost) > 0 else <Home />;
}
