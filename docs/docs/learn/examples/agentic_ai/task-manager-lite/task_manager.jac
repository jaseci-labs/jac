import from byllm.llm { Model }

glob llm = Model(model_name="gpt-4o");

node Task {
    has task:str = "";
    has date:str = "";
    has time:str = "";
}

node TaskHandling {
    def add_task(task: Task) -> str {
        self ++> task;
        return "Task added successfully";
    }
    def check_scheduled_tasks -> list[Task] {
        self ++> Task(
            task="Check scheduled tasks",
            date="2025-10-10",
            time="10:00:00"
        ); # Add a sample task for demonstration
        return [self --> (`?Task)];
    }
    def extract_task_info(utterance: str) -> str by llm(
        method="ReAct",
        tools=([self.add_task])
    );
    def summarize_tasks() -> str by llm(
        method="ReAct",
        tools=([self.check_scheduled_tasks])
    );
    def route_and_run(utterance: str) -> str by llm(
        method="ReAct",
        tools=([self.extract_task_info, self.summarize_tasks])
    );
    can execute with task_manager entry {
        print("[TaskHandling Node Activated]");
        response = self.route_and_run(visitor.utterance);
        print("→", response);
        visitor.response = response;
        visitor.node_type = "TaskHandling";
    }
}

node EmailHandling {
    def write_email_content(utterance: str) -> str by llm();
    def route_and_run(utterance: str) -> str by llm(
        method="ReAct",
        tools=([self.write_email_content])
    );
    can execute with task_manager entry {
        print("[EmailHandling Node Activated]");
        response = self.route_and_run(visitor.utterance);
        print("→", response);
        visitor.response = response;
        visitor.node_type = "EmailHandling";
    }
}

node GeneralChat {
    def chat(utterance: str) -> str by llm();
    can execute with task_manager entry {
        print("[GeneralChat Node Activated]");
        response = self.chat(visitor.utterance);
        print("→", response);
        visitor.response = response;
        visitor.node_type = "GeneralChat";
    }
}

enum RoutingNodes{
    TASK_HANDLING,
    EMAIL_HANDLING,
    GENERAL_CHAT
}

walker task_manager {
    has utterance: str = "";
    has response: str = "";
    has node_type: str = "";

    def route_to_node(utterance: str) -> RoutingNodes by llm();
    can execute with `root entry {
        routed_node_name = self.route_to_node(self.utterance);

        if routed_node_name == RoutingNodes.TASK_HANDLING {
            routed_node = here ++> TaskHandling();
        } elif routed_node_name == RoutingNodes.EMAIL_HANDLING {
            routed_node = here ++> EmailHandling();
        } elif routed_node_name == RoutingNodes.GENERAL_CHAT {
            routed_node = here ++> GeneralChat();
        }
        visit routed_node;

        # Report results for frontend
        report {
            "utterance": self.utterance,
            "response": self.response,
            "node_type": self.node_type,
            "routed_to": str(routed_node_name)
        };
    }
}