"""MkDocs hooks for Material: set the blog template for archive pages."""

from material.plugins.blog.structure import Archive

from mkdocs.config.defaults import MkDocsConfig
from mkdocs.structure.files import Files
from mkdocs.structure.pages import Page


def on_page_markdown(
    markdown: str, *, page: Page, config: MkDocsConfig, files: Files
) -> str:
    """Set the blog.html template on archive pages and return the unmodified markdown."""
    _ = (config, files)  # intentionally unused, required by hook signature
    if isinstance(page, Archive):
        page.meta["template"] = "blog.html"
    return markdown
