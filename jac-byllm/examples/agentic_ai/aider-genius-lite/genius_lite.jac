import from byllm.lib { Model }
import from pathlib { Path }

glob llm = Model(model_name="gpt-4o-mini");

# Simple task object with semantic annotations
obj Task {
    has name: str,
        type: str,
        details: str,
        priority: int = 1;
}

sem Task = "A specific development task with clear implementation requirements";
sem Task.name = "Clear, descriptive name for the task";
sem Task.type = "Task category: code, fix, docs, or test";
sem Task.details = "Specific implementation instructions";
sem Task.priority = "Task priority: 1=high, 2=medium, 3=low";

obj CodeResult {
    has task_name: str = "",
        code: str = "",
        status: str = "",
        feedback: str = "";
}

sem CodeResult = "Result of code generation task";
sem CodeResult.task_name = "Name of the completed task";
sem CodeResult.code = "Generated code solution";
sem CodeResult.status = "Task completion status: success or failed";
sem CodeResult.feedback = "Validation feedback and suggestions";

# Core AI functions
def create_plan(request: str) -> list[Task] by llm();
def generate_solution(task: Task) -> str by llm();
def validate_code(code: str, task: Task) -> str by llm();

# Nodes for walker traversal
node TaskNode {
    has task: Task = Task(name="", type="", details="", priority=1),
        code: str = "",
        feedback: str = "",
        status: str = "pending",
        result: CodeResult = CodeResult();

    def process_task {
        print(f"Working on: {self.task.name}");
        self.code = generate_solution(self.task);
        self.feedback = validate_code(self.code, self.task);
        self.status = "success" if self.feedback else "failed";
        print(f"Completed: {self.task.name}");

        # Create result
        self.result.task_name = self.task.name;
        self.result.code = self.code;
        self.result.status = self.status;
        self.result.feedback = self.feedback;
    }
}

node SummaryNode {
    has results: list[CodeResult] = [];

    def show_summary {
        output = f"Summary ({len(self.results)} tasks):\n\n";
        for result in self.results {
            status_icon = "SUCCESS" if result.status == "success" else "FAILED";
            output += f"{status_icon} {result.task_name}\n";
            if result.code and len(result.code) > 0 {
                code_preview = result.code[:300];
                if len(result.code) > 300 {
                    code_preview += "...";
                }
                output += f"   Code: {code_preview}\n";
            }
            if result.feedback {
                output += f"   Feedback: {result.feedback[:100]}...\n";
            }
            output += "\n";
        }
        print(output);
    }
}

# GeniusAgent as a walker
walker GeniusAgent {
    has request: str,
        tasks: list[Task] = [],
        results: list[CodeResult] = [],
        current_task_index: int = 0;

    can start with Root entry {
        print("Genius Lite - AI Coding Assistant");
        print("Simple, structured code generation with validation");
        print("=" * 50);
        self.tasks = create_plan(self.request);
        print(f"Created {len(self.tasks)} tasks");

        if len(self.tasks) > 0 {
            # Create task nodes and connect them
            task_nodes = [];
            for task in self.tasks {
                task_node = TaskNode();
                task_node.task = task;
                task_nodes.append(task_node);
            }
            # Connect nodes in sequence
            for i in range(len(task_nodes) - 1) {
                task_nodes[i] ++> task_nodes[i + 1];
            }
            # Connect last task node to summary
            summary_node = SummaryNode();
            summary_node.results = self.results;
            task_nodes[-1] ++> summary_node;
            # Start traversal from first task
            visit task_nodes[0];
        } else {
            print("No tasks created, ending execution");
        }
    }

    can process_task with TaskNode entry {
        # Let the node handle its own processing
        here.process_task();

        # Collect result from node and add to walker's results
        self.results.append(here.result);

        # Continue to next node
        visit [-->];
    }

    can show_summary with SummaryNode entry {
        # Pass results to the summary node
        here.results = self.results;
        # Let the node handle its own summary display
        here.show_summary();
    }
}

# API walker for frontend interaction
walker generate_code {
    has request: str;

    can execute with Root entry {
        print(f"Processing request: {self.request}");
        agent = GeniusAgent(request=self.request) spawn root;

        # Return the results
        report {
            "status": "success",
            "tasks": [
                {
                    "name": result.task_name,
                    "code": result.code,
                    "status": result.status,
                    "feedback": result.feedback
                } for result in agent.results
            ],
            "total_tasks": len(agent.results)
        };
    }
}

# Main execution (for testing without frontend)
glob user_request = "Create a Python calculator with basic math operations";

with entry {
    print(f"Demo: {user_request}");
    print("-" * 50);
}

glob agent = GeniusAgent(request=user_request) spawn root;

with entry {
    print("\nGenius Lite Demo Complete!");
    print("Features: Task planning, code generation, validation");
}
