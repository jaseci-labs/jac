import re;
import math;
import from core.ai { CodeReview }
import from core.github { RepoMeta }
import from core.timefmt { days_since }

obj RepoFeatures {
    has osp: bool = False,
        ai: bool = False,
        cl: bool = False,
        sv: bool = False,
        na: bool = False,
        tests: bool = False;
}

obj ScorePart {
    has category: str = "",
        label: str = "",
        pts: float = 0.0,
        max: float = 0.0,
        note: str = "";
}

obj ScoreBreakdown {
    has ai_review: CodeReview | None = None,
        total: int = 0,
        belt: str = "white",
        substance: int = 0,
        breadth: int = 0,
        craft: int = 0,
        community: int = 0,
        details: list[ScorePart] = [];
}

obj RepoAnalysis {
    has jac_files: int = 0,
        jac_lines: int = 0,
        jac_bytes: int = 0,
        other_code_bytes: int = 0,
        features: RepoFeatures = RepoFeatures(),
        readme: bool = False,
        readme_lines: int = 0,
        toml: bool = False,
        license: bool = False,
        ci: bool = False,
        docs: bool = False;

    def jac_pct -> int;
}

def analyze(files: dict[str, str]) -> RepoAnalysis;

def belt_for(total: int) -> str;

def score(meta: RepoMeta, an: RepoAnalysis) -> ScoreBreakdown;
