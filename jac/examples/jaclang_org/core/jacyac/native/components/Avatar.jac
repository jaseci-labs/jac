import from "@jac/mobui" { Image, View, Text }
import from core.jacyac.native.theme { makeStyles }
import from core.brand.theme { useTheme }
import from core.jacyac.identity { avatar_of }
import from core.jacyac.format { initial_of, handle_of }

def:pub Avatar(username: str, size: int, avatars: dict[str, str]) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    uri = avatar_of(avatars, username);
    shape = {"width": size, "height": size, "borderRadius": int(size / 2)};
    if uri {
        return
            <Image
                accessibilityLabel={handle_of(username)}
                source={{"uri": uri}}
                style={[styles.avatar, shape]}
            />;
    }
    return
        <View
            style={[
                shape,
                {
                    "alignItems": "center",
                    "justifyContent": "center",
                    "backgroundColor": C.elevated
                }
            ]}
        >
            <Text style={{"color": C.text, "fontSize": int(size / 2)}}>
                {initial_of(handle_of(username))}
            </Text>
        </View>;
}
