"""Bundled native ``keyword`` cross-backend equivalence fixture.

The sv entry uses CPython's keyword module; the na entry the bundled
`keyword.na.jac`, which mirrors CPython's kwlist/softkwlist verbatim
(ordering included). ES/JS opts out.
"""

import keyword;
import from keyword { iskeyword, issoftkeyword, kwlist, softkwlist }


def keyword_py -> dict {
    return {
        "n_kw": len(kwlist),
        "n_soft": len(softkwlist),
        "first": kwlist[0],
        "tenth": kwlist[10],
        "is_class": 1 if iskeyword("class") else 0,
        "is_banana": 1 if iskeyword("banana") else 0,
        "soft_match": 1 if issoftkeyword("match") else 0,
        "soft_class": 1 if issoftkeyword("class") else 0,
        "bare_is_def": 1 if keyword.iskeyword("def") else 0,

    };
}

cl def keyword_cl -> dict {
    return {};
}

na {
    def keyword_na -> dict[str, any] {
        return {
            "n_kw": len(kwlist),
            "n_soft": len(softkwlist),
            "first": kwlist[0],
            "tenth": kwlist[10],
            "is_class": 1 if iskeyword("class") else 0,
            "is_banana": 1 if iskeyword("banana") else 0,
            "soft_match": 1 if issoftkeyword("match") else 0,
            "soft_class": 1 if issoftkeyword("class") else 0,
            "bare_is_def": 1 if keyword.iskeyword("def") else 0,

        };
    }
}
