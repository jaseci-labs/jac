"""Home screen for {{name}}: the todo list.

Presentational - state and walker calls live in `app` (main.jac) and arrive
here as typed props, so the screen stays easy to reuse and to test. Only
`@jac/mobui` primitives are used; there is no HTML.
"""

import from "@jac/mobui" { View, Text, TextInput, ScrollView }
import from ..main { Todo }
import from ..theme { C, F, styles }
import from ..components.Button { Button }
import from ..components.Icon { Icon }

def:pub HomeScreen(
    todos: list[Todo],
    draft: str,
    onDraft: Callable[[str], None],
    onAdd: Callable[[], None]
) -> JsxElement {
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
        <View style={styles.header}>
            <View style={styles.titleRow}>
                <Icon name="sparkles" size={F.xl} color={C.accent}/>
                <Text style={styles.title}>{{name}}</Text>
            </View>
            <Text style={styles.subtitle}>
                {str(len(todos))} on the graph - they survive restarts.
            </Text>
        </View>
        <View style={styles.composer}>
            <TextInput
                style={styles.input}
                value={draft}
                placeholder="What needs doing?"
                placeholderTextColor={C.muted}
                onChangeText={onDraft}
                onSubmitEditing={onAdd}
            />
            <Button label="Add" onPress={onAdd} disabled={not draft.strip()}/>
        </View>
        {(
            <View style={styles.empty}>
                <Icon name="plus" size={F.lg} color={C.muted}/>
                <Text style={styles.emptyText}>
                    Nothing yet. Add your first todo above.
                </Text>
            </View>
        )
            if not todos
            else (
                <View style={styles.list}>
                    {[
                        <View key={idx} style={styles.row}>
                            <Icon name="check" size={F.md} color={C.accent}/>
                            <Text style={styles.rowText}>{todo.text}</Text>
                        </View> for (idx, todo) in enumerate(todos)
                    ]}
                </View>
            )}
    </ScrollView>
}
