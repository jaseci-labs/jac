"""Branch-reassigned str local boxed into a dict[str, any] return."""

def phi_str_box_py -> dict {
    flag = len("abc") > 1;
    label = "unset";
    if flag {
        label = "found";
    }
    return {"label": label, "flag": flag};
}

cl def phi_str_box_cl -> dict {
    return {};
}

na {
    def phi_str_box_na -> dict[str, any] {
        flag = len("abc") > 1;
        label = "unset";
        if flag {
            label = "found";
        }
        return {"label": label, "flag": flag};
    }
}
