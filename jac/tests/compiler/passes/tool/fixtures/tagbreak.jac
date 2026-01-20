#this file is part of formatter tests and is not meant to be run
class SemTokManager {
    """Initialize semantic token manager."""
    def init(self: SemTokManager, ir: uni.Module) -> None {
        self.aaaaastatic_sem_tokens:
            List[Tuple[lspt.Position, int, int, uni.AstSymbolNode]] = self.gen_sem_tok_node(
            ir
        );
    }
}

def walrus_example() {
    if ((x := 10) > 5) {
        print(x);
        b = a(
            11111111111111111111111111111111111111111111111111111111111111111111111111
        );
    }
}

with entry {
    c = (
        a()
        if 1
        and isinstance(a, int)
        and isinstance(a, int)
        and isinstance(a, int)
        and isinstance(a, int)
        and isinstance(a, int)
        else (
            999
            if isinstance(a, int)
            and isinstance(a, int)
            and isinstance(a, int)
            and isinstance(4, bool)
            else 7
        )
    );
    print("""This is a long
        line of code.""");
}

class ModuleManager {
    def clear_alerts_for_file(self: ModuleManager, file_path_fs: str) -> None {
        #list comprehension example
        self.warnings_had = [
            w
            for w in self.program
            if w.loc.mod_path != file_path_fs
        ];
        self.program.errors_had = [
            e
            for e in self.program.errors_haddddddddd
            if e.loc.mod_path != file_path_fs
        ];
        self.program.errors_had = [
            e
            for e in self.program.errors_haddddddddddddddddddddddddddddddddddddddddd
            if e.loc.mod_path != file_path_fs
        ];

        # dict comprehension example
        squares_dict = {x: x ** 2 for x in numbers};
        squares_dict = {
            x: x ** 2 for x in numberssssssssssssssssssssssssssssssssssssssssssssss
        };
        squares_dict = {
            x: x ** 2
            for x in numbersssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss
        };
        # set comprehension example
        squares_set = {x ** 2 for x in numbers};
        squares_set = {
            x ** 2 for x in numberssssssssssssssssssssssssssssssssssssssssssssssss
        };
        squares_set = {
            x ** 2
            for x in numbersssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss
        };

        # generator comprehension example
        squares_gen = (x ** 2 for x in numbers);
        squares_gen = (
            x ** 2 for x in numberssssssssssssssssssssssssssssssssssssssssssssssssssss
        );
        squares_gen = (
            x ** 2
            for x in numbersssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss
        );
    }
}

## expr as item extra space issue
with entry {
    with open(f"Apple{apple}.txt") as f {
        # Fix syntax highlighting
        print(f.read());
    }
}

def func_with_very_long_params(
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa: int,
    bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb: int,
) -> None {
    print(
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,
    );
}

def func_with_long_params(
    aaaaaaaaaaaaaaaaaaaaaa: int, bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb: int,
) -> None {
    print(
        aaaaaaaaaaaaaaaaaaaaaa, bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb, 1111111111111
    );
}

def func_with_short_params(a: int, b: int) -> None {
    print(a + b + c[5:]);
}

with entry {
    if (
        node_selected
        and node_selected.find_parent_of_type(uni.Archetype)
        or node_selected.find_parent_of_type(uni.ImplDef)
    ) {
        self_symbol = [
            lspt.CompletionItem(label='self', kind=lspt.CompletionItemKind.Variable)
        ];
    } else {
        self_symbol = [];
    }
    x = (
        1222222222
        and 2222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
    );
    a = 4 if True else 4;
}

import from typing { Any, Awaitable, Callable, Coroutine, Optional, ParamSpec, TypeVar }

import from jaclang.pycore.constant {
    JacSemTokenModifier as SemTokMod,
    JacSemTokenType as SemTokType,
}

"""Return diagnostics."""
def gen_diagnostics(
    from_path: str, errors: list[Alert], warnings: list[Alert]
) -> list[lspt.Diagnostic] {
    if (
        isinstance(node_selected, uni.Name)
        and node_selected.parent
        and isinstance(node_selected.parent, uni.ModulePath)
    ) {
        node_selected = node_selected.name_of;
    } elif (
        isinstance(node_selected, uni.Name)
        and node_selected.parent
        and isinstance(node_selected.parent, uni.ModulePath)
    ) {
        spec = node_selected.parent.parent.abs_path;
    }
}

@decorator
def x() {
    assert gg == 7;
}

@decorator()
class KK {}

# kkk
import pygame, random, math;

# fff
with entry {
    # gg
    a = 9;
}

# kkk
class X {}
class X {}

# comment
@decorator
def xxx() { }

# ddd
glob a = 7;
def get_node_info(self: JacLangServer, sym_node: uni.AstSymbolNode) -> Optional[str] {
    try {
        if isinstance(sym_node, uni.NameAtom) {
            sym_node = sym_node.name_of;
        }
        access = (sym_node.sym.access.value + ' ') if sym_node.sym else None;
        node_info = f"'('{(access if access else '')}{sym_node.sym_category.value}') '{sym_node.sym_name}";
        if sym_node.name_spec.clean_type {
            node_info += f"': '{sym_node.name_spec.clean_type}";
        }
        if (
            isinstance(sym_node, uni.AstSymbolNode)
            and isinstance(sym_node.name_spec.type, ClassType)
        ) {
            node_info += f"': '{sym_node.name_spec.type.shared.class_name}";
        }
        if (isinstance(sym_node, uni.AstDocNode) and sym_node.doc) {
            node_info += f"'\n'{sym_node.doc.value}";
        }
        if (isinstance(sym_node, uni.Ability) and sym_node.signature) {
            node_info += f"'\n'{sym_node.signature.unparse()}";
        }
    } except AttributeError as e {
        self.log_warning(f"'Attribute error when accessing node attributes: '{e}");
    }
    return node_info.strip();
}

class foo {
    """Get information about a node."""
    def get_node_info(
        self: JacLangServer, sym_node: uni.AstSymbolNode
    ) -> Optional[str] {
        if isinstance(sym_node, uni.AstVarNode) {
            var_name = sym_node.name;
            var_type = sym_node.var_type if sym_node.var_type else 'unknown';
            return f" 'Variable: ' {var_name} ', Type: ' {var_type} ";
        } elif isinstance(sym_node, uni.AstFuncNode) {
            func_name = sym_node.name;
            params = ', '.join(
                [f" {p.name} ': ' {p.param_type} " for p in sym_node.params]
            );
            return f" 'Function: ' {func_name} '(' {params} ')' ";
        }
    }
}

def x3() {
    if dest_type.is_class_instance() and src_type.is_class_instance() {
        print("x");
    }
    if (
        dest_type.is_class_instance()
        and src_type.is_class_instance()
        and src_type.is_class_instance()
    ) {
        print("x");
    }
    if (dest_type.is_class_instance() and src_type.is_class_instance()) {
        print("x");
    }
}

class HH {
    def test() -> Optional[str] {
        a = """!
hello
hru
""";
    }
}

enum Role0 { ADMIN = 'admin', USER = 'user', GUEST = 'guest', }

enum Role {
    ADMIN = 'admin',
    USER = 'user',
    GUEST = 'guest',
    ADMIN2 = "111111111111111111111111111111111111111111111111111111111111",
}

enum Y {
    A,  # 12
    B,  # 12
    C  #12
    # 1212
}

# 121212
def main() {
    print("Hello, World!");  # C1
    # This is a comment
    print(
        "Hello, World!"  # 123
    );  # C2
    if True {
        print("Condition met");  # C3
    }
}

obj Vehicle(ssdsd) {  # Has statements with type annotations (instance variables in obj)
    # Has statements with type annotations (instance variables in obj)
    """sadasd"""
    has name2: str,  # C1
        year2: int,  # C2
        name1: str;  # C3

    # Inline Python
    ::py::
    def py_method(self):
        return "Python code"
    ::py::

}

"""Type check with thread cancellation and proper debouncing."""
async def type_check(self: JacLangServer, file_path: str) -> None {
    # Cancel existing debounce timer for this file
    if file_path in self.debounce_timers {
        # Cancel existing type check thread for this file if running

        # Cancel existing type check thread for this file if running
        self.debounce_timers[file_path].cancel();
    }

    # Cancel existing type check thread for this file if running
    if file_path in self.cancel_tokens {
        self.cancel_tokens[file_path].set();
    }

    # Create new cancellation token for the upcoming type check
    self.cancel_tokens[file_path] = threading.Event();
    # self.cancel_tokens[file_path] = mythreading.Event();

    # Create a debounced function that will run the actual type check
    def debounced_type_check() -> None {
        # Start new thread for type checking
        print(" debounced_type_check ->", time.time(), file=sys.stderr);
        self.type_check_threads[file_path] = threading.Thread(
            target=self.type_check_file,
            args=(file_path, self.cancel_tokens[file_path])
        );
        self.type_check_threads[file_path].start();
        self.type_check_threads[file_path].join();
    }

    # Set up debounce timer with the actual type check function
    self.debounce_timers[file_path] = threading.Timer(0.5, debounced_type_check);
    self.debounce_timers[file_path].start();

    # Wait for the current type check thread to finish (if any)
    await asyncio.to_thread(self.debounce_timers[file_path].join);
}

cl import from jac:client_runtime {
    jacLogin,
    jacLogout,
    jacSignup,
    createRouter,
    Route,
    Link,
    navigate,
    createState,
}

cl {
    # Reactive state management
    glob _state = createState({"tweets": [], "loading": False});
    glob appState = _state[0];
    glob setAppState = _state[1];

    # Shared data model for client/server
    obj ClientTweet {
        has username: str = "";
        has id: str = "";
        has content: str = "";
        has likes: list = [];
        has comments: list = [];
    }

    # UI Components - Render a single tweet card
    def TweetCard(tweet: ClientTweet) -> any {
        return
            <div
                class="tweet-card"
                style={{
                    "border": "1px solid #e1e8ed",
                    "padding": "15px",
                    "margin": "10px 0",
                    "borderRadius": "8px"
                }}
            >
                <div
                    class="tweet-header"
                    style={{"fontWeight": "bold", "marginBottom": "8px"}}
                >
                    @{tweet.username}
                </div>
                # Random comment
                <div class="tweet-content" style={{"marginBottom": "12px"}}>
                    {tweet.content} # Another andom comment
                </div>
                <div class="tweet-actions" style={{"display": "flex", "gap": "15px"}}>
                    <button
                        onclick={like_tweet_action(tweet.id)}
                        style={{"padding": "5px 10px", "cursor": "pointer"}}
                    >
                        Like ({tweet.likes.length})
                    </button>
                    <button style={{"padding": "5px 10px"}}>
                        Comment ({tweet.comments.length})
                    </button>
                </div>
            </div>;
    }

    # UI Components - Render a single tweet card
    def TweetCard2(tweet: ClientTweet) -> any {
        return
            <div class="tweet-actions" style={{"display": "flex", "gap": "15px"}}>
                <button style={{"padding": "5px 10px"}}>
                    Comment ({tweet.comments.length})
                </button>
            </div>;
    }

    # UI Components - Render a single tweet card
    def TweetCard3(tweet: ClientTweet) -> any {
        return (
            <div class="tweet-actions" style={{"display": "flex", "gap": "15px"}}>
                <button style={{"padding": "5px 10px"}}>
                    Comment ({tweet.comments.length})
                </button>
            </div>
        );
    }

    # Handle liking a tweet - calls server walker directly
    # The compiler automatically transforms this to __jacCallFunction at compile time!
    async def like_tweet_action(tweet_id: str) -> any {
        try {
            result = await like_tweet(tweet_id);
            print("Tweet liked:", result);
            # Re-render feed after like
            window.location.reload();
        } except Exception as e {
            print("Error liking tweet:", e);
        }
    }
}

def x(
    # comment
) {
    print(
        "111"  #
    );
}

def gg() {
#1234
}

obj A {
    # 123
    def x() {
    # 123
    }
}

def x(
    x: int = 123
    # comment
) {
    print(
        "111"  #
    );
}

with entry {
    visit [-->(`?Year:year==self.target_day.year)];
}

# Match statement comment preservation
def test_match_comments(x: int) {
    match x {
        # comment before first case
        case 1:
            # comment in case body
            print("one");

        # comment between cases
        case _:
            print("other");

    }
    return
    # All lines and columns are 1-Based
    True;
}

def generate_greeting_code(name: str) -> str by models["code-gen"];

glob llm = MockLLM(
         # model_name="gpt-4o-mini",
         model_name="mockllm",
         outputs=[
             Person(
                 full_name='Albert Einstein',
                 year_of_death='1955',
                 personality=Personality.EXTROVERT,
             ),

         ],
     );
