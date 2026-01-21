cl {
    # Central place for UI-related decisions

    def:pub normalizeSize(size: str) -> str {
        return size if size in ["sm", "md", "lg"] else "md";
    }

    def:pub normalizeVariant(variant: str) -> str {
        return variant if variant in ["primary", "secondary"] else "primary";
    }

    def:pub buttonClassNames(
        variant: str,
        size: str,
        disabled: bool
    ) -> str {

        v = normalizeVariant(variant);
        s = normalizeSize(size);

        classes = [
            "btn",
            "btn-" + v,
            "btn-" + s
        ];

        if disabled {
            classes.push("btn-disabled");
        }

        return classes.join(" ");
    }

    def:pub isButtonClickable(disabled: bool, onClick: any) -> bool {
        return (not disabled) and onClick != None;
    }

}