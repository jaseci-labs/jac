"""{{name}} - a cross-platform mobUI app.

One source tree runs on the web (react-native-web) and on iOS / Android
(React Native via Expo). The top of this file is the backend: `Todo` nodes
persist on the graph, and the two `walker:pub` endpoints are the API the UI
calls with `root spawn`. `app` is the client shell: it owns the state, talks
to the walkers, and renders `screens/` with `@jac/mobui` primitives only - a
raw `<div>` is a compile error (E1105) in a mobUI app.
"""

import from "@jac/mobui" { View }
import from .theme { styles }
import from .screens.Home { HomeScreen }

node Todo {
    has text: str;
}

walker:pub AddTodo {
    """Append a todo and report the created node."""
    has text: str,
        reports: list[Todo] = [];

    can add with Root entry {
        report here ++> Todo(text=self.text);
    }
}

walker:pub ListTodos {
    """Report every todo on the graph, one report per node."""
    has reports: list[Todo] = [];

    can collect with Root entry {
        visit [-->[?:Todo]];
    }

    can gather with Todo entry {
        report here;
    }
}

def:pub app -> JsxElement {
    has todos: list[Todo] = [],
        draft: str = "";

    # Load what is already on the graph once, when the app mounts.
    async can with entry {
        result = root spawn ListTodos();
        todos = result.reports;
    }

    async def addTodo -> None {
        text = draft.strip();
        if not text {
            return;
        }
        result = root spawn AddTodo(text=text);
        todos = todos + [result.reports[0]];
        draft = "";
    }

    <View style={styles.screen}>
        <HomeScreen
            todos={todos}
            draft={draft}
            onDraft={lambda (t: str) { draft = t; }}
            onAdd={lambda { addTodo(); }}
        />
    </View>
}
