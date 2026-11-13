"""By-llm call sites with tools, each beside a twin without tools, whose answer types carry sems."""

import from jaclang.byllm.lib { MockLLM }

obj Channel {
    has name: str;
}

sem Channel.name = "The channel's display name.";

obj Slug {
    has text: str,
        tags: list[str],
        channel: Channel;
}

sem Slug = "A URL slug for one video, never a placeholder.";

sem Slug.text = "Lowercase words joined by hyphens.";

sem Slug.tags = "Topic tags taken from the title.";

enum Mood: str { HAPPY = "happy", SAD = "sad" }

sem Mood = "How the speaker feels.";

sem Mood.HAPPY = "Upbeat, laughing or celebrating.";

sem Mood.SAD = "Grieving, lonely or let down.";

def lookup(query: str) -> str {
    return f"found {query}";
}

glob finish_llm: any = None;

def make_slug(title: str) -> Slug by finish_llm(tools=[lookup]);

def make_slug_direct(title: str) -> Slug by finish_llm();

def make_slugs(titles: str) -> list[Slug] by finish_llm(tools=[lookup]);

def make_slugs_direct(titles: str) -> list[Slug] by finish_llm();

def read_mood(text: str) -> Mood by finish_llm(tools=[lookup]);

def read_mood_direct(text: str) -> Mood by finish_llm();
