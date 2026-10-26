impl RichText(text: str) -> JsxElement {
    <span>
        {for (i, seg) in enumerate(text_segments(text)) {
            if seg["k"] == "link" and seg["t"].startswith("/") {
                <Link
                    key={str(i)}
                    to={seg["t"]}
                    className="break-all text-primary underline-offset-2 hover:underline"
                >
                    {seg["t"]}
                </Link>
            } elif seg["k"] == "link" {
                <a
                    key={str(i)}
                    href={seg["t"]}
                    target="_blank"
                    rel="noreferrer"
                    className="break-all text-primary underline-offset-2 hover:underline"
                >
                    {seg["t"]}
                </a>
            } elif seg["k"] == "mention" {
                <span key={str(i)} className="font-medium text-primary">
                    {seg["t"]}
                </span>
            } else {
                <span key={str(i)}>{seg["t"]}</span>
            }
        }}
    </span>
}
