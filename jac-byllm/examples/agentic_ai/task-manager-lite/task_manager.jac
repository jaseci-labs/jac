import from byllm.llm { Model }
import time;

glob llm = Model(model_name="gpt-4o");

node Task {
    has task: str = "",
        date: str = "",
        time: str = "";
}

node TaskHandling {
    def get_current_time -> str {
        return time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime());
    }

    def add_task(task: str, date: str, time: str) -> str {
        task_created = Task(task=task, date=date, time=time);
        self ++> task_created;
        return "Task added successfully";
    }

    def summarize_tasks -> str {
        scheduled_tasks = [self-->(?:Task)];
        return str(scheduled_tasks);
    }

    def route_and_run(utterance: str) -> str by llm(
        tools=([self.add_task, self.get_current_time, self.summarize_tasks])
    );

    can execute with task_manager entry {
        print("[TaskHandling Node Activated]");
        response = self.route_and_run(visitor.cur_task.task);
        print("→", response);
        report {
            "utterance": visitor.cur_task.task,
            "response": response,
            "node_type": self.__class__.__name__
        };
    }
}

node EmailHandling {
    def write_email_content(utterance: str) -> str by llm();
    def route_and_run(utterance: str) -> str by llm(
        tools=([self.write_email_content])
    );

    can execute with task_manager entry {
        print("[EmailHandling Node Activated]");
        response = self.route_and_run(visitor.cur_task.task);
        print("→", response);
        report {
            "utterance": visitor.cur_task.task,
            "response": response,
            "node_type": self.__class__.__name__
        };
    }
}

node GeneralChat {
    def chat(utterance: str) -> str by llm();
    can execute with task_manager entry {
        print("[GeneralChat Node Activated]");
        response = self.chat(visitor.cur_task.task);
        print("→", response);
        report {
            "utterance": visitor.cur_task.task,
            "response": response,
            "node_type": self.__class__.__name__
        };
    }
}

enum RoutingNodes { TASK_HANDLING, EMAIL_HANDLING, GENERAL_CHAT }

sem RoutingNodes.TASK_HANDLING = "Creating/deleting/updating/summarizing tasks to TODO";
sem RoutingNodes.EMAIL_HANDLING = "EmailHandling node for composing and managing emails";
sem RoutingNodes.GENERAL_CHAT = "Get intelligent answers, productivity advice, and general AI assistance across various topics.";

obj TaskPartition {
    has task: str,
        agent_type: RoutingNodes;
}

sem TaskPartition = "Distinct Tasks within Main Task (Can be the main task itself)";
sem TaskPartition.task = "Description of the Task to be performed";
sem TaskPartition.agent_type = "Type of the agent that should handle this Task";

walker task_manager {
    has utterance: str = "",
        cur_task: TaskPartition = None;

    def route_to_node(utterance: str) -> RoutingNodes by llm();
    def plan_tasks(main_task: str) -> list[TaskPartition] by llm();
    can execute with Root entry {
        # routed_node_name = self.route_to_node(self.utterance);
        subtasks = self.plan_tasks(self.utterance);

        print("[Planned Subtasks]:", subtasks);

        node_map = {
            RoutingNodes.TASK_HANDLING: TaskHandling,
            RoutingNodes.EMAIL_HANDLING: EmailHandling,
            RoutingNodes.GENERAL_CHAT: GeneralChat
        };
        for subtask in subtasks {
            node_type = node_map[subtask.agent_type];
            routed_node = [-->(?:node_type)];
            if not routed_node {
                routed_node = here ++> node_type();
            }
            self.cur_task = subtask;
            visit routed_node;
        }
    }
}
