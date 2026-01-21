cl import from .componentsLogic {
    buttonClassNames,
    isButtonClickable
}

cl {
    def:pub Button(
        label: str,
        onClick: any,
        variant: str = "primary",
        size: str = "md",
        disabled: bool = False
    ) -> any {

        classes = buttonClassNames(
            variant,
            size,
            disabled
        );

        clickable = isButtonClickable(disabled, onClick);

        return <button
            className={classes}
            disabled={disabled}
            onClick={onClick if clickable else None}
        >
            {label}
        </button>;
    }
}
