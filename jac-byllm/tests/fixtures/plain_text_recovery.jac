"""Fixture to test recovery when the LLM returns plain text instead of calling finish_tool.

Simulates the gpt-4o failure mode where the model responds with conversational text
rather than using finish_tool as instructed, and verifies the Bug 2B recovery path:
- First dispatch: MockLLM returns a plain string (no tool calls).
- invoke detects no tool calls + finish_tool present → adds recovery message and re-prompts.
- Second dispatch: MockLLM returns MockToolCall(finish_tool, ...) → result extracted correctly.
"""
import from byllm.lib { MockLLM, MockToolCall }

"""A chat message from one person."""
obj Chat {
    has person: str,
        message: str;
}

"""A dummy side-effect tool. Its presence causes finish_tool to be auto-added."""
def get_mood(character: str) -> str {
    return "cheerful";
}

"""Local finish_tool used only to construct MockToolCall.
Must be named exactly 'finish_tool' so is_finish_call() recognises it."""
def finish_tool(final_output: Chat) -> Chat {
    return final_output;
}

glob llm = MockLLM(
    model_name="mockllm",
    config={
        "outputs": [
            # Round 1: plain conversational text — the gpt-4o failure mode.
            "Greetings traveller, I have wares to trade!",
            # Round 2 (recovery re-prompt): LLM correctly calls finish_tool.
            MockToolCall(
                tool=finish_tool,
                args={"final_output": Chat(person="Merchant", message="Greetings traveller, I have wares to trade!")}
            ),
        ],
        "verbose": False
    }
);

"""Generate the NPC's opening line given a player name."""
def generate_npc_line(player_name: str, npc_name: str) -> Chat by llm(tools=[get_mood]);

with entry {
    result = generate_npc_line("Elara", "Merchant");
    print("PERSON: " + result.person);
    print("MESSAGE: " + result.message);
}
