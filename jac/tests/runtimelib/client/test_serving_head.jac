"""Tests for HeaderBuilder head-tag emission.

Attribute values must be quoted: an unquoted `content=` attribute dies at its
first space under any HTML parser, so link-preview crawlers (Discord, Slack,
iMessage) see only the first word of a site's description.
"""

import from jaclang.runtimelib.client.serving { HeaderBuilder }

test "meta content with spaces survives as one quoted attribute" {
    hb = HeaderBuilder(
        meta_data={
            "title": "The Jac Site",
            "description": "One language, one compiler"
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<meta name="description" content="One language, one compiler" />' in head;
    assert '<title>The Jac Site</title>' in head;
    assert '<meta charset="UTF-8" />' in head;
    assert '<meta name="viewport" content="width=device-width,initial-scale=1" />' in head;
}

test "og and twitter keys emit rich preview tags" {
    hb = HeaderBuilder(
        meta_data={
            "og_title": "The Jac Site",
            "og_description": "One language, one compiler",
            "og_site_name": "jaclang.org",
            "og_image": "https://jaclang.org/static/assets/jac-logo.png",
            "twitter_card": "summary"
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<meta property="og:title" content="The Jac Site" />' in head;
    assert '<meta property="og:description" content="One language, one compiler" />' in head;
    assert '<meta property="og:site_name" content="jaclang.org" />' in head;
    assert '<meta property="og:image" content="https://jaclang.org/static/assets/jac-logo.png" />' in head;
    assert '<meta name="twitter:card" content="summary" />' in head;
}

test "attribute values with embedded quotes are escaped" {
    hb = HeaderBuilder(
        meta_data={"description": 'say "wuuut" often'}, function_name="app"
    );
    head = hb.build_head();
    assert '<meta name="description" content="say &quot;wuuut&quot; often" />' in head;
}

test "link tags quote rel and href" {
    hb = HeaderBuilder(
        meta_data={"icon": "/static/assets/jac-logo.png"}, function_name="app"
    );
    head = hb.build_head();
    assert '<link rel="icon" href="/static/assets/jac-logo.png" />' in head;
}
