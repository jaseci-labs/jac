"""c2jac fidelity bands: style vs behavior vs hole.

Style sites stay as twin-band W/E diagnostics. Behavior and hole sites also
quarantine the containing function so lenient ingest cannot run wrong answers
or leave mid-body `__c_unsupported__` landmines.
"""

enum FidelityBand {
    STYLE = "style",
    BEHAVIOR = "behavior",
    HOLE = "hole"
}

# W4208 remains BEHAVIOR for residual lossy for-lowerings (e.g. unmappable
# condition → `while True`). Continue-in-for is now faithful: promotable fors
# become IterForStmt, and while-lowerings splice the step before continue.
glob STYLE_NUMS: set[int] = {4201, 4204, 4209, 4210, 4211},
     BEHAVIOR_NUMS: set[int] = {4202, 4203, 4205, 4206, 4207, 4208},
     HOLE_NUMS: set[int] = {4290};

def fidelity_band(num: int) -> FidelityBand {
    if num in HOLE_NUMS {
        return FidelityBand.HOLE;
    }
    if num in BEHAVIOR_NUMS {
        return FidelityBand.BEHAVIOR;
    }
    return FidelityBand.STYLE;
}

def band_quarantines(band: FidelityBand) -> bool {
    return band == FidelityBand.BEHAVIOR or band == FidelityBand.HOLE;
}

def band_of_code(code: str) -> str {
    # "W4290" / "E4205" -> band value string
    if len(code) < 2 {
        return FidelityBand.STYLE.value;
    }
    try {
        num = int(code[1:]);
    } except ValueError {
        return FidelityBand.STYLE.value;
    }
    return fidelity_band(num).value;
}

def diag_num_of_code(code: str) -> int | None {
    if len(code) < 2 {
        return None;
    }
    try {
        return int(code[1:]);
    } except ValueError {
        return None;
    }
}
