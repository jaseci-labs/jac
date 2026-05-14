"""Test that `{#* ... *#}` works as a Jac-native JSX comment (no rendered output)."""

cl {
    def:pub App() -> Any {
        return <div>
            <h1>
                Hello
            </h1>
            {#* JSX_COMMENT_PROBE replace this button later *#}
            <button>
                Click
            </button>
            {#* trailing JSX_COMMENT_PROBE *#}
        </div>;
    }
}
