from material.plugins.blog.structure import Archive


def on_page_markdown(markdown, *, page, config, files):
    if isinstance(page, Archive):
        page.meta["template"] = "blog.html"
