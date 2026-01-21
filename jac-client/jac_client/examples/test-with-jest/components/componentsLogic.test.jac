cl import from .componentsLogic {
    normalizeSize,
    normalizeVariant,
    buttonClassNames,
    isButtonClickable
}

test normalizeSize_allows_valid_sizes {
    assert normalizeSize("sm") == "sm";
    assert normalizeSize("lg") == "lg";
}

test normalizeSize_falls_back_to_md {
    assert normalizeSize("xl") == "md";
}

test normalizeVariant_allows_valid_variants {
    assert normalizeVariant("secondary") == "secondary";
}

test normalizeVariant_falls_back_to_primary {
    assert normalizeVariant("danger") == "primary";
}

test buttonClassNames_builds_correct_base_classes {
    classes = buttonClassNames("primary", "md", False);
    assert "btn" in classes;
    assert "btn-primary" in classes;
    assert "btn-md" in classes;
}

test buttonClassNames_adds_disabled_class {
    classes = buttonClassNames("primary", "md", True);
    assert "btn-disabled" in classes;
}

test isButtonClickable_false_when_disabled {
    assert isButtonClickable(True, lambda: None) == False;
}

test isButtonClickable_false_when_handler_missing {
    assert isButtonClickable(False, None) == False;
}

test isButtonClickable_true_when_enabled_with_handler {
    assert isButtonClickable(False, lambda: None) == True;
}
