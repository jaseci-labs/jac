"""Tasks column -- owns task list state, fetches on mount."""

sv import from ..main { Task, get_tasks, add_task, toggle_task, delete_task }

import from .TaskItem { TaskItem }

def:pub TasksPanel -> JsxElement {
    has tasks: list[Task] = [],
        taskText: str = "",
        tasksLoading: bool = True;

    async can with entry {
        tasks = await get_tasks();
        tasksLoading = False;
    }

    async def addTask {
        if not taskText.strip() {
            return;
        }
        task = await add_task(taskText.strip());
        tasks = tasks + [task];
        taskText = "";
    }

    async def toggleTask(id: str) {
        updated = await toggle_task(id);
        if updated is not None {
            tasks = [updated if jid(t) == id else t for t in tasks];
        }
    }

    async def deleteTask(id: str) {
        await delete_task(id);
        tasks = [
            t
            for t in tasks
            if jid(t) != id
        ];
    }

    def handleKeyPress(e: KeyboardEvent) {
        if e.key == "Enter" {
            addTask();
        }
    }

    remaining = len(
        [
            t
            for t in tasks
            if not t.done
        ]
    );

    return
        <div class="column">
            <h2>Today's Tasks</h2>
            <div class="input-row">
                <input
                    class="input"
                    value={taskText}
                    onChange={lambda e: ChangeEvent { taskText = e.target.value; }}
                    onKeyPress={handleKeyPress}
                    placeholder="What needs to be done today?"
                />
                <button class="btn-add" onClick={lambda { addTask(); }}>Add</button>
            </div>
            {(<div class="loading-msg">Loading tasks...</div>)
                if tasksLoading
                else (
                    <div>
                        {(<div class="empty-msg">No tasks yet. Add one above!</div>)
                            if len(tasks) == 0
                            else (
                                <div>
                                    {[
                                        <TaskItem
                                            key={jid(t)}
                                            task={t}
                                            onToggle={lambda { toggleTask(jid(t)); }}
                                            onDelete={lambda { deleteTask(jid(t)); }}
                                        /> for t in tasks
                                    ]}
                                </div>
                            )}
                    </div>
                )}
            <div class="count">
                {remaining} {("task" if remaining == 1 else "tasks")} remaining
            </div>
        </div>;
}
