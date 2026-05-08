"""Tasks column -- owns task list state, spawns walkers for CRUD."""

sv import from ..main { Task, AddTask, ListTasks, ToggleTask, DeleteTask }

import from .TaskItem { TaskItem }

def:pub TasksPanel -> JsxElement {
    has tasks: list[Task] = [],
        taskText: str = "",
        tasksLoading: bool = True;

    async can with entry {
        result = root spawn ListTasks();
        tasks = result.reports[0] if result.reports else [];
        tasksLoading = False;
    }

    async def addTask {
        if not taskText.strip() {
            return;
        }
        response = root spawn AddTask(title=taskText);
        tasks = tasks + [response.reports[0]];
        taskText = "";
    }

    async def toggleTask(id: str) {
        response = root spawn ToggleTask(task_id=id);
        updated = response.reports[0];
        tasks = [updated if jid(t) == id else t for t in tasks];
    }

    async def deleteTask(id: str) {
        root spawn DeleteTask(task_id=id);
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
