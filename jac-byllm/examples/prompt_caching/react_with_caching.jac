"""Prompt caching example — ReAct agent on an Anthropic model.

Prompt caching is automatic for Claude models. The system prompt and tool
schemas are cached after the first LLM call. Check cached tokens in the output.
"""

glob COUNTRIES: dict = {
         "France": {"pop": "68M", "capital": "Paris", "gdp": "$3.05T"},
         "Japan": {"pop": "125M", "capital": "Tokyo", "gdp": "$4.23T"},
         "Brazil": {"pop": "216M", "capital": "Brasilia", "gdp": "$2.13T"},
         "India": {"pop": "1.4B", "capital": "New Delhi", "gdp": "$3.94T"},
         "Germany": {"pop": "84M", "capital": "Berlin", "gdp": "$4.46T"},
         "Nigeria": {"pop": "224M", "capital": "Abuja", "gdp": "$477B"},
         "Mexico": {"pop": "129M", "capital": "Mexico City", "gdp": "$1.32T"}
     };

"""Look up a fact about a country. fact_type: pop, capital, or gdp."""
def lookup(country: str, fact_type: str) -> str {
    entry = COUNTRIES.get(country);
    if entry is None {
        return f"No data for {country}";
    }
    return entry.get(fact_type, f"Unknown: {fact_type}");
}

sem lookup = "Look up a single fact about a country.";
sem lookup.country = "Country name";
sem lookup.fact_type = "One of: pop, capital, gdp";

def research(question: str) -> str by llm(tools=[lookup], stream=True, logging=True);

glob response = "";

with entry {
    for event in research(
        "Look up pop, capital, and gdp for France, Japan, Brazil, India, "
        "Germany, Nigeria, and Mexico. Rank by GDP."
    ) {
        if event.event_type == "chunk" {
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
            input_t = int(total.get("prompt_tokens", 0));
            print(f"\n--- Usage ({len(per_call)} LLM calls) ---");
            print(
                f"Input:  {input_t}  Output: {total.get(
                    'completion_tokens', 0
                )}  Cached: {cached}"
            );
            if input_t > 0 {
                print(f"Cache hit rate: {round(cached / input_t * 100, 1)}%");
            }
        }
    }
    print("\n--- Response ---");
    print(response);
}
