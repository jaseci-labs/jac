"""Client module that calls def:pub server functions from a separate file.

This tests that the compiler generates __jacCallFunction RPC stubs when
def:pub functions (not walkers) are called from a separate .cl.jac file.
The sv import triggers stub generation so the browser can call server
functions over HTTP.
"""

import from "@jac/runtime" { jacIsLoggedIn }

# Server function imports - tells compiler these are def:pub endpoints
sv import from separated_defpub { add_task, get_tasks, toggle_task }

def:pub app -> JsxElement {
    has tasks: list = [],
        taskText: str = "",
        tasksLoading: bool = True;

    async can with entry {
        tasks = await get_tasks();
        tasksLoading = False;
    }

    async def addTask -> None {
        if taskText.strip() {
            task = await add_task(taskText.strip());
            tasks = tasks.concat([task]);
            taskText = "";
        }
    }

    async def toggleTask(id: str) -> None {
        await toggle_task(id);
        tasks = tasks.map(
            lambda t: any -> any {
                return {"id": t.id, "title": t.title, "done": not t.done}
                if t.id == id else t;
            }
        );
    }

    return
        <div>
            <h1>Tasks</h1>
            <input
                value={taskText}
                onChange={lambda e: any -> None { taskText = e.target.value; }}
            />
            <button onClick={addTask}>Add</button>
            {[
                <div key={t.id}>
                    <span>{t.title}</span>
                    <button onClick={lambda -> None { toggleTask(t.id); }}>Toggle</button>
                </div> for t in tasks
            ]}
        </div>;
}
