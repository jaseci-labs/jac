"""Single task row -- presentational; toggle and delete are passed in."""

sv import from ..main { Task }

def:pub TaskItem(
    task: Task, onToggle: Callable[[], None], onDelete: Callable[[], None]
) -> JsxElement {
    return
        <div class="task-item">
            <input type="checkbox" checked={task.done} onChange={onToggle}/>
            <span class={"task-title " + ("task-done" if task.done else "")}>
                {task.title}
            </span>
            {if task.category and task.category != "other" {
                <span class="category">{task.category}</span>
            }}
            <button class="btn-delete" onClick={onDelete}>X</button>
        </div>;
}
