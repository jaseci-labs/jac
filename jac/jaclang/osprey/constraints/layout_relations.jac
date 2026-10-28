def node_vars(base_id: int) -> dict[str, Variable];


def _term(v: Variable, coefficient: float = 1.0) -> Term;


def _constraint(
    terms: list[Term],
    constant: float = 0.0,
    relation: Relation = Relation.EQ,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> Constraint;


def affine_constraint(
    expression: Expression,
    relation: Relation = Relation.EQ,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> Constraint;


def above(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def below(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def left_of(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def right_of(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def align_left(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def align_right(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def align_top(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def align_bottom(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def center_x(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def center_y(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def fill_width(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def fill_height(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def same_width(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def same_height(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def width_nonnegative(
    layout_node: dict[str, Variable], strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def height_nonnegative(
    layout_node: dict[str, Variable], strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def preferred_width(
    layout_node: dict[str, Variable],
    preferred: float,
    strength: StrengthTier = StrengthTier.WEAK,
) -> list[Constraint];


def preferred_height(
    layout_node: dict[str, Variable],
    preferred: float,
    strength: StrengthTier = StrengthTier.WEAK,
) -> list[Constraint];


def vertical_flow(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint];


def horizontal_flow(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint];


def column(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint];


def row(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint];


def align_center_x(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def align_center_y(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];
