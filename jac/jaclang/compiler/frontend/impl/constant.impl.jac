impl JacSemTokenModifier.as_str_list -> list[str] {
    return [
        i.name.lower()
        for i in JacSemTokenModifier
        if i.name
    ];
}

impl client_state_setter_name(var_name: str) -> str {
    if not var_name {
        return "";
    }
    return f"set{var_name[0].upper()}{var_name[1:]}";
}

impl is_borrow_kind(k: OwnershipKind) -> bool {
    return k == OwnershipKind.BORROW or k == OwnershipKind.MUT_BORROW;
}

impl is_mut_kind(k: OwnershipKind) -> bool {
    return k == OwnershipKind.MUT_BORROW;
}
