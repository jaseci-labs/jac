"""Wikipedia Tools for the MTLLM framework."""

from jaclang import JacMachineInterface as _

from mtllm.types import Tool

import wikipedia as wikipedia_lib


@_.sem(
    "A tool that gets the summary of a Wikipedia article.",
    {
        "title": "Title of the Wikipedia article to get the summary for.",
    },
)
def get_wikipedia_summary(title: str) -> str:
    """Get the summary of the related article from Wikipedia."""
    try:
        return wikipedia_lib.summary(title)
    except Exception:
        options = wikipedia_lib.search(title, results=5, suggestion=True)
        raise Exception(f"Could not get summary for {title}. Similar titles: {options}")


wikipedia_summary = Tool(
    get_wikipedia_summary,
)

wikipedia_get_related_titles = Tool(
    wikipedia_lib.search,
)


@_.sem(
    "A tool that gets the whole page from Wikipedia.",
    {
        "title": "Title of the Wikipedia article to get the whole page for.",
    },
)
def wikipedia_get_page(title: str) -> dict:
    """Get the page from Wikipedia."""
    try:
        pg = wikipedia_lib.page(title)
        return {
            "title": pg.title,
            "content": pg.content,
            "url": pg.url,
            "summary": pg.summary,
        }
    except wikipedia_lib.DisambiguationError as e:
        raise Exception(f"Could not get page for {title}. Similar titles: {e.options}")


wikipedia_get_whole_page = Tool(
    wikipedia_get_page,
)
