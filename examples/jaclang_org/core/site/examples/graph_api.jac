node Task {
    has title: str,
        done: bool = False;
}

walker:pub add_task {
    has title: str,
        reports: list[dict[str, str]] = [];

    can create with Root entry {
        task = Task(title=self.title);
        root ++> task;
        report {"id": jid(task)};
    }
}

walker:pub list_tasks {
    has reports: list[list[str]] = [];

    can fetch with Root entry {
        report [t.title for t in [-->][?:Task]];
    }
}

# jac run graph_api.jac  ->  POST /walker/add_task
