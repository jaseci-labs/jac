"""Prompt caching example — ReAct agent on an Anthropic model."""

glob COUNTRY_DB: dict = {
    "France":    {"population": "68M",   "capital": "Paris",       "language": "French",         "currency": "EUR", "gdp": "$3.05T"},
    "Japan":     {"population": "125M",  "capital": "Tokyo",       "language": "Japanese",       "currency": "JPY", "gdp": "$4.23T"},
    "Brazil":    {"population": "216M",  "capital": "Brasilia",    "language": "Portuguese",     "currency": "BRL", "gdp": "$2.13T"},
    "India":     {"population": "1.4B",  "capital": "New Delhi",   "language": "Hindi, English", "currency": "INR", "gdp": "$3.94T"},
    "Germany":   {"population": "84M",   "capital": "Berlin",      "language": "German",         "currency": "EUR", "gdp": "$4.46T"},
    "Nigeria":   {"population": "224M",  "capital": "Abuja",       "language": "English",        "currency": "NGN", "gdp": "$477B"},
    "Australia": {"population": "26M",   "capital": "Canberra",    "language": "English",        "currency": "AUD", "gdp": "$1.68T"},
    "Mexico":    {"population": "129M",  "capital": "Mexico City", "language": "Spanish",        "currency": "MXN", "gdp": "$1.32T"}
};


def get_country_facts(country: str, fact_type: str) -> str {
    entry = COUNTRY_DB.get(country);
    if entry is None {
        return f"No data for {country}";
    }
    fact = entry.get(fact_type);
    if fact is None {
        return f"Unknown fact '{fact_type}'. Available: {', '.join(entry.keys())}";
    }
    return f"{country} {fact_type}: {fact}";
}

sem get_country_facts = "Look up a single fact about a country. Call once per country per fact.";
sem get_country_facts.country = "Country name (e.g. 'France')";
sem get_country_facts.fact_type = "One of: population, capital, language, currency, gdp";


def research_countries(question: str) -> str
    by llm(tools=[get_country_facts], stream=True, logging=True);


with entry {
    response = "";
    for event in research_countries(
        "Research France, Japan, Brazil, India, Germany, Nigeria, Australia, and Mexico. "
        "For each country look up population, capital, language, currency, and gdp. "
        "Then rank all 8 by GDP highest to lowest."
    ) {
        if event.event_type == "tool_call" {
            print(f"  -> {event.data.get('tool', '')}({event.data.get('args', {})})");
        } elif event.event_type == "chunk" {
            response += event.data.get("content", "");
        } elif event.event_type == "usage" {
            total = event.data.get("total", {});
            per_call = event.data.get("per_call", []);
            cached = 0;
            for call in per_call {
                cached += int(
                    call.get("cache_read_input_tokens", 0)
                    or (call.get("prompt_tokens_details") or {}).get("cached_tokens", 0)
                    or 0
                );
            }
            input_tokens = int(total.get("prompt_tokens", 0));
            print(f"\n--- Usage ({len(per_call)} LLM calls) ---");
            print(f"Input tokens:  {input_tokens}");
            print(f"Output tokens: {total.get('completion_tokens', 0)}");
            print(f"Cached tokens: {cached}");
            if input_tokens > 0 {
                print(f"Cache hit rate: {round(cached / input_tokens * 100, 1)}%");
            }
        }
    }
    print("\n--- Response ---");
    print(response);
}
