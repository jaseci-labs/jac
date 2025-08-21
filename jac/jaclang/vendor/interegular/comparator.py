from collections import namedtuple
from dataclasses import dataclass
from itertools import combinations
from typing import List, Tuple, Any, Dict, Iterable, Set, FrozenSet, Optional

from interegular import InvalidSyntax, REFlags
from interegular.fsm import FSM, Alphabet, anything_else
from interegular.patterns import Pattern, Unsupported, parse_pattern
from interegular.utils import logger, soft_repr


@dataclass
class ExampleCollision:
    """
    Captures the full text of an example collision between two regex.
    `main_text` is the part that actually gets captured by the two regex
    `prefix` is the part that is potentially needed for lookbehinds
    `postfix` is the part that is potentially needed for lookahead
    """
    prefix: str
    main_text: str
    postfix: str

    def format_multiline(self, intro: str = "Example Collision: ", indent: str = "",
                         force_pointer: bool = False) -> str:
        """
        Formats this example somewhat similar to a python syntax error.
        - intro is added on the first line
        - indent is added on the second line
        The three parts of the example are concatenated and `^` is used to underline them.

        ExampleCollision(prefix='a', main_text='cd', postfix='ef').format_multiline()

        leads to

        Example Collision: acdef
                             ^^

        This function will escape the character where necessary to stay readable.
        if `force_pointer` is False, the function will not produce the second line if only main_text is set
        """
        if len(intro) < len(indent):
            raise ValueError("Can't have intro be shorter than indent")
        prefix = soft_repr(self.prefix)
        main_text = soft_repr(self.main_text)
        postfix = soft_repr(self.postfix)
        text = f"{prefix}{main_text}{postfix}"
        if len(text) != len(main_text):
            whitespace = ' ' * (len(intro) - len(indent) + len(prefix))
            pointers = '^' * len(main_text)
            return f"{intro}{text}\n{indent}{whitespace}{pointers}"
        else:
            return f"{intro}{text}"

    @property
    def full_text(self):
        return self.prefix + self.main_text + self.postfix


class Comparator:
    """
    A class that represents the main interface for comparing a list of regex to each other.
    It expects a dictionary of arbitrary labels mapped to `Pattern` instances,
    but there is a utility function to create the instances `from_regex` strings.

    The main interface function all expect the abitrary labels to be given, which
    then get mapped to the correct `Pattern` and/or `FSM` instance.

    There is a utility function `mark(a,b)` which allows to mark pairs that shouldn't
    be checked again by `check`.
    """

    def __init__(self, patterns: Dict[Any, Pattern]):
        self._patterns = patterns
        self._marked_pairs: Set[FrozenSet[Any]] = set()
        if not patterns:  # `isdisjoint` can not be called anyway, so we don't need to create a valid state
            return
        self._alphabet = Alphabet.union(*(p.get_alphabet(REFlags(0)) for p in patterns.values()))[0]
        prefix_postfix_s = [p.prefix_postfix for p in patterns.values()]
        self._prefix_postfix = max(p[0] for p in prefix_postfix_s), max(p[1] for p in prefix_postfix_s)
        self._fsms: Dict[Any, FSM] = {}
        self._know_pairs: Dict[Tuple[Any, Any], bool] = {}

    def get_fsm(self, a: Any) -> FSM:
        if a not in self._fsms:
            try:
                self._fsms[a] = self._patterns[a].to_fsm(self._alphabet, self._prefix_postfix)
            except Unsupported as e:
                self._fsms[a] = None
                logger.warning(f"Can't compile Pattern to fsm for {a}\n     {repr(e)}")
            except KeyError:
                self._fsms[a] = None  # In case it was thrown away in `from_regexes`
        return self._fsms[a]

    def isdisjoint(self, a: Any, b: Any) -> bool:
        if (a, b) not in self._know_pairs:
            fa, fb = self.get_fsm(a), self.get_fsm(b)
            if fa is None or fb is None:
                self._know_pairs[a, b] = True  # We can't know. Assume they are disjoint
            else:
                self._know_pairs[a, b] = fa.isdisjoint(fb)
        return self._know_pairs[a, b]

    def check(self, keys: Iterable[Any] = None, skip_marked: bool = False) -> Iterable[Tuple[Any, Any]]:
        if keys is None:
            keys = self._patterns
        for a, b in combinations(keys, 2):
            if skip_marked and self.is_marked(a, b):
                continue
            if not self.isdisjoint(a, b):
                yield a, b

    def get_example_overlap(self, a: Any, b: Any, max_time: float = None) -> ExampleCollision:
        pa, pb = self._patterns[a], self._patterns[b]
        needed_pre = max(pa.prefix_postfix[0], pb.prefix_postfix[0])
        needed_post = max(pa.prefix_postfix[1], pb.prefix_postfix[1])

        # We use the optimal alphabet here instead of the general one since that
        # massively improves performance by every metric.
        alphabet = pa.get_alphabet(REFlags(0)).union(pb.get_alphabet(REFlags(0)))[0]
        fa, fb = pa.to_fsm(alphabet, (needed_pre, needed_post)), pb.to_fsm(alphabet, (needed_pre, needed_post))
        intersection = fa.intersection(fb)
        if max_time is None:
            max_iterations = None
        else:
            # We calculate an approximation for that value of max_iterations
            # that makes sure for this function to finish in under max_time seconds
            # This values will heavily depend on CPU, python version, exact patterns
            # and probably more factors, but this should generally be in the correct
            # ballpark.
            max_iterations = int((max_time - 0.09)/(1.4e-6 * len(alphabet)))
        try:
            text = next(intersection.strings(max_iterations))
        except StopIteration:
            raise ValueError(f"No overlap between {a} and {b} exists")
        text = ''.join(c if c != anything_else else '?' for c in text)
        if needed_post > 0:
            return ExampleCollision(text[:needed_pre], text[needed_pre:-needed_post], text[-needed_post:])
        else:
            return ExampleCollision(text[:needed_pre], text[needed_pre:], '')

    def is_marked(self, a: Any, b: Any) -> bool:
        return frozenset({a, b}) in self._marked_pairs

    @property
    def marked_pairs(self):
        return self._marked_pairs

    def count_marked_pairs(self):
        return len(self._marked_pairs)

    def mark(self, a: Any, b: Any):
        self._marked_pairs.add(frozenset({a, b}))

    @classmethod
    def from_regexes(cls, regexes: Dict[Any, str]):
        patterns = {}
        for k, r in regexes.items():
            try:
                patterns[k] = parse_pattern(r)
            except (Unsupported, InvalidSyntax) as e:
                logger.warning(f"Can't compile regex to Pattern for {k}\n     {repr(e)}")
        return cls(patterns)
