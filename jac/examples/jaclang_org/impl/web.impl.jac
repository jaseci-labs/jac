impl app(children: any) -> JsxElement {
    can with entry {
        load_analytics();
    }
    return <>{children}</>;
}

impl load_analytics -> None {
    host = window.location.hostname;
    if host != "jaclang.org" and host != "www.jaclang.org" {
        return;
    }
    if document.getElementById("gtm-loader") {
        return;
    }
    head: any = document.head;
    init: any = document.createElement("script");
    init.text = "window.dataLayer = window.dataLayer || [];"
        + " function gtag(){dataLayer.push(arguments);}"
        + " gtag('js', new Date());";
    head.appendChild(init);
    loader: any = document.createElement("script");
    loader.id = "gtm-loader";
    loader.async = True;
    loader.src = "https://www.googletagmanager.com/gtm.js?id=" + GTM_ID;
    head.appendChild(loader);
}
