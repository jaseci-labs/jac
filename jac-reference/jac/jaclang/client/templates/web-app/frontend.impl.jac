"""Implementations for the {{name}} frontend component."""

impl app.loadMessages -> None {
    result = root spawn ListMessages();
    messages = result.reports;
}

impl app.postMessage(e: FormEvent) -> None {
    e.preventDefault();
    if not author.strip() or not text.strip() {
        return;
    }
    result = root spawn PostMessage(author=author, text=text);
    messages = messages + [result.reports[0]];
    text = "";
}
