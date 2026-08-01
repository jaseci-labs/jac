"""HeaderBuilder must emit crawler-parseable meta tags.

Unquoted attribute values end at the first space per HTML parsing rules,
so `content=The Jac Programming Language` reads back as content="The" -
exactly what link-preview crawlers (LinkedIn, Slack, X) then display.
"""

import from jaclang.runtimelib.client.serving { HeaderBuilder }


test "attribute values are quoted so spaces survive crawlers" {
    hb = HeaderBuilder(
        meta_data={
            "title": "The Jac Programming Language",
            "description": "One language, one compiler, the whole stack.",
            "og_title": "The Jac Programming Language",
            "og_description": "One language, one compiler, the whole stack.",
            "og_url": "https://jaclang.org/",
            "icon": "/static/assets/jac-logo.png",
            "meta_color_scheme": "dark light"
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<title>The Jac Programming Language</title>' in head;
    assert '<meta property="og:title" content="The Jac Programming Language" />'
        in head;
    assert '<meta name="description" content="One language, one compiler, the whole stack." />'
        in head;
    assert '<link rel="icon" href="/static/assets/jac-logo.png" />' in head;
    assert '<meta name="color-scheme" content="dark light" />' in head;
    assert "content=The " not in head;
    assert "content=One " not in head;
}


test "og property names keep their spec underscores" {
    hb = HeaderBuilder(
        meta_data={
            "og_site_name": "jaclang.org",
            "og_image_secure_url": "https://jaclang.org/logo.png",
            "og_locale_alternate": "en_GB",
            "og_image_width": "1200"
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<meta property="og:site_name" content="jaclang.org" />' in head;
    assert '<meta property="og:image:secure_url" content="https://jaclang.org/logo.png" />'
        in head;
    assert '<meta property="og:locale:alternate" content="en_GB" />' in head;
    assert '<meta property="og:image:width" content="1200" />' in head;
    assert "og:site:name" not in head;
}


test "twitter keys emit twitter colon names" {
    hb = HeaderBuilder(
        meta_data={
            "twitter_card": "summary",
            "twitter_image": "https://jaclang.org/logo.png",
            "twitter_image_alt": "Jac logo"
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<meta name="twitter:card" content="summary" />' in head;
    assert '<meta name="twitter:image" content="https://jaclang.org/logo.png" />'
        in head;
    assert '<meta name="twitter:image:alt" content="Jac logo" />' in head;
}


test "values are escaped inside their quotes" {
    hb = HeaderBuilder(meta_data={"og_title": 'A "B" & <C>'}, function_name="app");
    head = hb.build_head();
    assert 'content="A &quot;B&quot; &amp; &lt;C&gt;"' in head;
}
