"""Mock entry point for integration testing — uses MockLLM instead of real API."""
import os;
import re;
import from byllm.lib { MockLLM, MockToolCall }
import from byllm.types { StreamEvent }
import from tools { calculate, run_and_test_python_code }
import from mock_responses {
    load_concept_agent_outputs,
    load_math_agent_outputs,
    load_research_agent_outputs,
    load_code_agent_outputs
}

glob llms = {
    "llm1": MockLLM(
        model_name="mockllm",
        config={"outputs": [], "verbose": False},
    ),

    "llm2": MockLLM(
        model_name="mockllm",
        config={"outputs": [], "verbose": False},
    ),

    "llm3": MockLLM(
        model_name="mockllm",
        config={"outputs": [], "verbose": False},
    ),
};

obj ResearchSummary {
    has summary: str,
        key_points: list[str],
        confidence: str;
}

node ConceptAgent {

    def explain(topic: str) -> str by llms["llm1"](stream=True, logging=True);

    can handle with Supervisor entry {
        result = self.explain(visitor.query);
        full_content = "";
        for event in result {
            if event.event_type == "chunk" {
                full_content += event.data.get("content", "");
            }
        }
        visitor.agent_result = {"agent": "ConceptAgent", "response": full_content};
    }
}

node MathAgent {

    def solve(problem: str) -> str by llms["llm2"](
        method="ReAct",
        tools=[calculate],
        max_react_iterations=3,
        stream=True,
        logging=True
    );

    can handle with Supervisor entry {
        result = self.solve(visitor.query);
        full_content = "";
        for event in result {
            if event.event_type == "chunk" {
                full_content += event.data.get("content", "");
            }
        }
        visitor.agent_result = {"agent": "MathAgent", "response": full_content};
    }
}

node ResearchAgent {

    def analyze(query: str) -> ResearchSummary by llms["llm2"](
        method="Reason"
    );

    can handle with Supervisor entry {
        result = self.analyze(visitor.query);

        # Store result on the walker for it to report later
        visitor.agent_result = {
            "agent": "ResearchAgent",
            "summary": result.summary,
            "key_points": result.key_points,
            "confidence": result.confidence
        };
    }
}

node CodeAgent {

    def generate_code(task: str) -> str by llms["llm3"](
        tools=[run_and_test_python_code],
        max_react_iterations=3,
        stream=True,
        logging=True
    );

    can handle with Supervisor entry {
        result = self.generate_code(visitor.query);
        full_content = "";
        for event in result {
            if event.event_type == "chunk" {
                full_content += event.data.get("content", "");
            }
        }
        visitor.agent_result = {"agent": "CodeAgent", "response": full_content};
    }
}

walker:pub Supervisor {

    has query: str;

    can route with Root entry {

        if not [root --> (?:ConceptAgent)] { root ++> ConceptAgent(); }
        if not [root --> (?:MathAgent)] { root ++> MathAgent(); }
        if not [root --> (?:ResearchAgent)] { root ++> ResearchAgent(); }
        if not [root --> (?:CodeAgent)] { root ++> CodeAgent(); }

        # Load mock outputs based on query content before routing.
        # Use re to detect math expressions (digits near operators) to avoid
        # false positives on hyphens inside words like "fine-tuning".
        q = self.query;
        if "machine learning" in q.lower() or "explain" in q.lower() {
            load_concept_agent_outputs(llms);
        } elif re.search(r'\d\s*[\+\-\*\/]', q) or re.search(r'[\+\*\/]\s*\d', q) {
            load_math_agent_outputs(llms);
        } elif "write" in q.lower() or "code" in q.lower() or "python" in q.lower() or "function" in q.lower() {
            load_code_agent_outputs(llms);
        } else {
            load_research_agent_outputs(llms, ResearchSummary);
        }

        # Initialize result storage (dynamic attribute, not exposed in API)
        self.agent_result = None;

        visit [-->] by llms["llm2"](
            show_params=True,
            verbose=False,
            incl_info={
                "instruction": "Select exactly ONE agent node to visit. Return only ONE node.",
                "user_query": self.query,
            }
        );
    }

    can collect_result with Root exit {
        # Report collected results - this works in REST API
        if self.agent_result is not None {
            report self.agent_result;
            del self.agent_result;  # Remove from walker to avoid duplication in response
        }
    }
}
