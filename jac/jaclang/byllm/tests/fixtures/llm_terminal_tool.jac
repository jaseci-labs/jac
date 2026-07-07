"""Fixtures for the terminal-tool feature (`by llm(finish_tool=fn)`).

A terminal tool ends the ReAct loop and yields the call's output. finish_tool= marks the
function so every Tool wrapping it (including a MockToolCall's) is terminal, which lets
these mock-driven tests exercise the real detection and recovery paths. Each `by llm()`
function is called once, so the per-glob MockLLM output scripts are consumed once.
"""

import from jaclang.byllm.lib { MockLLM, MockToolCall }

def lookup(q: str) -> str {
    return "data";
}

def finish(answer: str) -> str {
    return answer;
}

# Worker tool, then the terminal tool -> loop ends and returns the terminal's output.
glob term_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [
        MockToolCall(tool=lookup, args={"q": "x"}),
        MockToolCall(tool=finish, args={"answer": "done"})
    ]}
);
def run_agent(task: str) -> str by term_llm(tools=[lookup], finish_tool=finish);

# Natural exit (plain text, no terminal call). Because a terminal tool is designated,
# recovery forces it: the next (recovery) turn calls finish -> "forced".
glob recover_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [
        MockToolCall(tool=lookup, args={"q": "x"}),
        "I think I am done.",
        MockToolCall(tool=finish, args={"answer": "forced"})
    ]}
);
def run_agent_recover(task: str) -> str by recover_llm(tools=[lookup], finish_tool=finish);

# No designated terminal: a plain str agent may answer in text (natural exit, no forced
# recovery). Only a worker tool is present; byllm's auto finish_tool is not enforced for
# a str return, so the second output (plain text) ends the run without a third turn.
def plain_worker(q: str) -> str {
    return "w";
}
glob plain_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [
        MockToolCall(tool=plain_worker, args={"q": "x"}),
        "plain answer"
    ]}
);
def run_plain(task: str) -> str by plain_llm(tools=[plain_worker]);
