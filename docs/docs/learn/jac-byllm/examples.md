# byLLM Tutorials and Examples


## Tutorials

<div class="grid cards" markdown>

-   **RPG Game Level Genaration**

    ---

    *A Tutorial on building an AI-Intergrated RPG Game using byLLM.*

    [Start](./../../examples/mtp_examples/rpg_game/){ .md-button }

-   **Fantacy Trading Game**

    ---

    *A text-based trding game where non-player charaters are handled using large language models. This is use tool calling for game mechanics such as bargaining at shops.*

    [Start](./../../examples/mtp_examples/fantasy_trading_game/){ .md-button }

-   **AI-Powered Multimodal MCP Chatbot**

    ---

    *This Tutorial shows how to implemented a agentic AI application using the byLLM package and object-spatiol programming. In additionn MCP integration is demonstrated here.*

    [Start](./../../examples/rag_chatbot/Overview/){ .md-button }

</div>


## Examples

This section collects the example byllm programs bundled in `jac-byllm/examples/`. Examples are grouped by type. For each example the source is shown in a tab so you can quickly inspect the code.

### Core Examples
Small, focused examples that show common byLLM patterns for integrating LLMs in Jac programs.

Repository location: [jac-byllm/examples/core_examples](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/core_examples)

??? note "Core examples (code)"

    === "personality_finder.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/core_examples/personality_finder.jac"
        ```

    === "level_genarator.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/core_examples/level_genarator.jac"
        ```

### Vision / Multimodal examples

Examples that demonstrate multimodal usage (images and video) with byLLM and vision-capable LLMs. Accompanying media files live alongside the Jac code in the repo.

Repository location: [jac-byllm/examples/vision](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/vision)

??? note "Vision / Multimodal examples (code)"
    Vision-enabled examples that combine image/video inputs with byLLM workflows. Only the Jac code files are shown below; accompanying media are in the examples folder (e.g. `person.png`, `receipt.jpg`, `mugen.mp4`).

    === "math_solver.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/vision/math_solver.jac"
        ```

    === "personality_finder.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/vision/personality_finder.jac"
        ```

    === "receipt_analyzer.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/vision/receipt_analyzer.jac"
        ```

    === "mugen.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/vision/mugen.jac"
        ```

### Tool-calling examples

Examples showing how to orchestrate external tools (APIs, search, or internal tool servers) from Jac/byLLM and how to coordinate multi-agent workflows.

Repository location: [jac-byllm/examples/tool_calling](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/tool_calling)

??? note "Tool-calling examples (code)"
    Examples that demonstrate calling external tools, tool orchestration, or multi-agent interactions.

    === "wikipedia_react.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/tool_calling/wikipedia_react.jac"
        ```

    === "marketing_agency.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/tool_calling/marketing_agency.jac"
        ```

    === "fantasy_trading_game.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/tool_calling/fantasy_trading_game.jac"
        ```

    === "debate_agent.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/tool_calling/debate_agent.jac"
        ```

### Agentic AI examples

Small agentic patterns and lightweight multi-step reasoning examples (multi-turn planning, simple agents). These live under the agentic_ai examples folder.

Repository location: [jac-byllm/examples/agentic_ai](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/agentic_ai)

??? note "Agentic AI examples (code)"
    Examples that demonstrate small agentic behaviors and light-weight multi-step reasoning.

    === "friendzone_lite.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/agentic_ai/friendzone_lite.jac"
        ```

    === "genius_lite.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/agentic_ai/genius_lite.jac"
        ```

### Microbenchmarks

Short, single-purpose microbenchmarks for probing model behavior and performance on targeted tasks. Used for evaluations done in the MTPm paper.

Repository location: [jac-byllm/examples/microbenchmarks](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/microbenchmarks)

??? note "Microbenchmarks (code)"
    Small microbenchmarks and single-purpose prompts useful for testing model behavior and performance.

    === "text_to_type.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/microbenchmarks/text_to_type.jac"
        ```

    === "odd_word_out.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/microbenchmarks/odd_word_out.jac"
        ```

    === "joke_gen.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/microbenchmarks/joke_gen.jac"
        ```

    === "grammar_checker.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/microbenchmarks/grammar_checker.jac"
        ```

    === "translator.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/microbenchmarks/translator.jac"
        ```

    === "essay_review.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/microbenchmarks/essay_review.jac"
        ```

    === "expert_answer.jac"
        ```jac linenums="1"
        --8<-- "jac-byllm/examples/microbenchmarks/expert_answer.jac"
        ```
