node Task {
    has id: int,
        title: str,
        completed: bool = False;
}

walker CreateTask {
    has id: int,
        title: str;

    can create with Root entry {
        new_task = here ++> Task(id=self.id, title=self.title);
        report new_task ;
    }
}

walker GetAllTasks {
    can read with Root entry{
        tasks = [-->];
        report tasks;
    }
}

walker GetTask {
    has id: int;

    can get with Root entry{
        for task in [-->]{
            if (self.id == task.id){
                report task;
            }
        }
    }
}

walker CompleteTask {
    has id: int;

    can complete with Root entry {
        for task in [-->Task] {
            if (self.id == task.id){
                visit task;
            }
        }
    }

    can mark_complete with Task entry {
        here.completed = True;
        report here ;  # here is the visited task
    }
}

walker DeleteTask {
    has id: int;

    can visit_node with Root entry {
        for task in [-->] {
            if (self.id == task.id){
                visit task;
            }
        }
    }

    can delete with Root entry {
        del here;
        report {"deleted": True, "id": self.id};
    }
}
