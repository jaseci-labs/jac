"""A tool-using by-llm call site whose answer type carries type and field sems."""

import from jaclang.byllm.lib { MockLLM }

obj Slug {
    has text: str,
        tags: list[str];
}

sem Slug = "A URL slug for one video, never a placeholder.";

sem Slug.text = "Lowercase words joined by hyphens.";

sem Slug.tags = "Topic tags taken from the title.";

def lookup(query: str) -> str {
    return query;
}

glob finish_llm: any = None;

def make_slug(title: str) -> Slug by finish_llm(tools=[lookup]);
