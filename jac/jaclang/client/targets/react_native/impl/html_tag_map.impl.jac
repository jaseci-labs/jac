impl supported_rn_html_tags -> frozenset {
    tags: set[str] = set();
    for tag in RN_HTML_VIEW_TAGS {
        tags.add(tag);
    }
    for tag in RN_HTML_TEXT_TAGS {
        tags.add(tag);
    }
    for tag in RN_HTML_SPECIAL_TAGS {
        tags.add(tag);
    }
    return frozenset(tags);
}

impl rn_tag_suggestions -> dict[str, str] {
    suggestions: dict[str, str] = {};
    for tag in RN_HTML_VIEW_TAGS {
        suggestions[tag] = "View";
    }
    for tag in RN_HTML_TEXT_TAGS {
        suggestions[tag] = "Text";
    }
    suggestions.update(
        {
            "ul": "ScrollView",
            "ol": "ScrollView",
            "button": "Pressable",
            "a": "Pressable",
            "input": "TextInput",
            "textarea": "TextInput",
            "img": "Image"
        }
    );
    return suggestions;
}
