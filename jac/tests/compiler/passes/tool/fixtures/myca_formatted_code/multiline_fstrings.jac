with entry {
    context_str = "woooo";
    # Construct prompt here
    prompt = (
        f"Myca is a personal productivity platform that helps people manage many aspects of their life better and become better versions of themselves. "
        f"It is morning time right now and I am starting my day."
        f"{context_str}\n"
        f"Given this information, answer a query for me.\n"
        f"Some rules to follow:\n"
        f"1. Avoid statements like 'Based on the context, ...' or "
        f"'The context information ...' or anything along "
        f"those lines.\n"
        f"Write a quick and motivational message to start my day off right. Focus your message on planning, intentionality, positivity, and productivity."
        f"Talk to me like you are my friend. Use personable wording and tone. Use emojis if it makes sense."
        f"Keep the response within just one sentence. This will be shown as a mobile push notification.\n"
        f"Answer: "
    );
}
