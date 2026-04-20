"""Fixture: SV returns objects containing enums to CL.

Tests that enum values survive the codespace boundary
and can be used for comparison/display on the client.
"""

enum Priority {
    LOW = "low",
    MEDIUM = "medium",
    HIGH = "high"
}

enum Status {
    PENDING,
    IN_PROGRESS,
    DONE
}

obj Task {
    has title: str,
        priority: Priority = Priority.MEDIUM,
        status: Status = Status.PENDING;
}

def:pub create_task(title: str, priority: str) -> Task {
    return Task(title=title);
}

def:pub get_tasks_by_priority(priority: str) -> list[Task] {
    return [];
}

cl {
    sv import from .typed_return_enum { create_task, get_tasks_by_priority }

    def:pub app -> JsxElement {
        has tasks: list = [];

        async def addHighPriority(title: str) -> None {
            task = await create_task(title, "high");
            tasks = tasks + [task];
        }

        return <div>
            {[<span key={t.title}>{t.title}: {t.priority}</span> for t in tasks]}
        </div>;
    }
}
