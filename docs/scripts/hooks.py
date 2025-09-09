# from material.plugins.blog.structure import Archive


# def on_page_markdown(markdown, *, page, config, files):
#     if isinstance(page, Archive):
#         page.meta["template"] = "blog.html"

"""Hooks for customizing MkDocs Material blog structure."""

from material.plugins.blog.structure import Archive

def on_page_markdown(
    markdown: str, 
    *, 
    page, 
    config, 
    files
) -> str:
    """
    Modify the page markdown for Archive pages to use a custom template.

    Args:
        markdown (str): The markdown content of the page.
        page: The page object being processed.
        config: The MkDocs configuration object.
        files: The files collection.

    Returns:
        str: The (possibly modified) markdown content.
    """
    if isinstance(page, Archive):
        page.meta["template"] = "blog.html"
    return markdown