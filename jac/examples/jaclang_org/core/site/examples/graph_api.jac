node Task {
    has title: str,
        done: bool = False;
}

walker:pub add_task {
    has title: str;

    can create with Root entry {
        task = Task(title=self.title);
        root ++> task;
        report {"id": jid(task)};
    }
}

walker:pub list_tasks {
    can fetch with Root entry {
        report [t.title for t in [-->][?:Task]];
    }
}

# jac start graph_api.jac  ->  POST /walker/add_task
