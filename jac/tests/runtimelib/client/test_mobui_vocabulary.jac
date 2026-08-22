"""Tests for the @jac/mobui vocabulary surface.

@jac/mobui is a sealed, Jac-owned component vocabulary: each name is
imported from react-native under an RN-prefixed alias and re-exported
unprefixed. The two lists are hand-maintained, so this pins them against
each other -- an import with no matching glob:pub is invisible to mobUI
authors, and a re-export with no import would not resolve.
"""

import os;
import from pathlib { Path }

# The mobui module ships with core under jaclang/runtimelib/client/.
glob _mobui_file = (
         Path(os.path.dirname(__file__)).parent.parent.parent
         / "jaclang"
         / "runtimelib"
         / "client"
         / "client_mobui.jac"
     ),
     _EXPECTED = [
         "View",
         "Text",
         "Pressable",
         "TextInput",
         "Image",
         "ScrollView",
         "StyleSheet",
         "Animated",
         "Easing",
         "KeyboardAvoidingView",
         "Keyboard",
         "Platform",
         "ActivityIndicator",
         "useWindowDimensions",
         "FlatList",
         "SectionList",
         "RefreshControl",
         "Modal",
         "Switch",
         "StatusBar",
         "Dimensions",
         "Alert",
         "Linking"
     ];

test "mobui vocabulary re-exports every primitive it imports" {
    assert _mobui_file.exists() , f"client_mobui.jac not found at {_mobui_file}";
    content = _mobui_file.read_text();

    for name in _EXPECTED {
        assert f"{name} as RN{name}" in content , (
            f"{name} is not imported from react-native in client_mobui.jac"
        );
        assert f"{name} = RN{name}" in content , (
            f"{name} is imported but never re-exported via glob:pub"
        );
    }
}

test "mobui vocabulary depends on react-native alone" {
    # A second UI package here would become a required dependency of every
    # mobUI web build too, so keep the import surface to react-native only.
    content = _mobui_file.read_text();
    assert "from 'react-native'" in content;
    assert "react-native-web" not in content;
    assert "react-native-safe-area-context" not in content;
}
