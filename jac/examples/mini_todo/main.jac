import from dateutil.parser { parse }  #<-- from Python
import from "canvas-confetti" { default as confetti }  #<-- from npm

node Todo {
    has title: str,
        category: str = "other",
        due: str = "",
        priority: int = 0,
        done: bool = False;
}

enum Category: int { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

def categorize(title: str) -> Category by llm();

def priority_score(title: str) -> int {
    score: int = 0;
    for c in title {
        if c == "!" {
            score = score + 20;
        }
    }
    if "urgent" in title {
        score = score + 50;
    }
    if score > 100 {
        score = 100;
    }
    return score;
}

def:pub add_todo(title: str) -> Todo {
    try {
        result = categorize(title);
        category = str(result).split(".")[-1].lower();
    } except Exception {
        category = "other (setup AI key)";
    }
    try {
        due = parse(title, fuzzy=True).strftime("%a %b %d");
    } except Exception {
        due = "";
    }
    todo = Todo(
        title=title, category=category, due=due, priority=priority_score(title)
    );
    root ++> todo;
    return todo;
}

def:pub get_todos -> list[Todo] {
    return [root-->][?:Todo];
}

def:pub app -> JsxElement {
    has todos: list[Todo] = [],
        text: str = "";

    async can with entry {
        todos = await get_todos();
    }

    async def add {
        if text.strip() {
            todo = await add_todo(text.strip());
            todos = todos + [todo];
            text = "";
            confetti();
        }
    }

    return
        <div>
            <input
                value={text}
                onChange={lambda (e: ChangeEvent) { text = e.target.value; }}
                onKeyPress={lambda (e: KeyboardEvent) { if e.key == "Enter" { add(); }}}
                placeholder="Add a todo..."
            />
            <button onClick={lambda { add(); }}>Add</button>
            {for t in todos {
                <p key={jid(t)}>
                    [{t.priority}]{t.title} ({t.category}){" — due " + t.due
                        if t.due
                        else ""}
                </p>
            }}
        </div>;
}
