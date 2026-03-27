"""Fixture: Walker spawn returns typed node objects to CL.

Tests that walker reports containing typed node/edge objects
are properly hydrated on the client side.
"""

node Project {
    has name: str,
        description: str = "",
        members: list = [];
}

node Task {
    has title: str,
        assignee: str = "",
        done: bool = False;
}

edge Owns {}

edge AssignedTo {}

walker create_project {
    has name: str,
        description: str = "";

    can create with Root entry {
        proj = here ++> Project(name=self.name, description=self.description);
        report proj;
    }
}

walker add_task {
    has title: str,
        assignee: str = "";

    can add with Project entry {
        task = here ++> Task(title=self.title, assignee=self.assignee);
        report task;
    }
}

walker get_project_tasks {
    can enter_project with Project entry {
        visit [-->[?:Task]];
    }

    can report_task with Task entry {
        report here;
    }
}

cl {
    def:pub app -> JsxElement {
        has projects: list = [],
            tasks: list = [];

        async can with entry {
            result = root spawn create_project(name="My Project", description="Test");
            project = result.reports[0][0];
            projects = [project];
        }

        async def loadTasks(projectId: str) -> None {
            result = projectId spawn get_project_tasks();
            tasks = result.reports;
        }

        return <div>
            {[<div key={p.name}>
                <h2>{p.name}</h2>
                <p>{p.description}</p>
            </div> for p in projects]}
        </div>;
    }
}
