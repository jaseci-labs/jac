def _tolist[C: Iterable](src: C) -> list[any];

def _tolist_any(src: any) -> list[any];

def _add_default(a: any, b: any) -> any;

def:pub count(start: int | float = 0, step: int | float = 1) -> Iterator[any];

def _count_gen(start: int | float, step: int | float) -> Iterator[any];

def:pub cycle[C: Iterable](iterable: C) -> Iterator[any];

def _cycle_gen[C: Iterable](src: C) -> Iterator[any];

def:pub repeat(object: any, times: int | None = None) -> Iterator[any];

def _repeat_gen(x: any, times: int | None) -> Iterator[any];

def:pub accumulate[C: Iterable](
    iterable: C, func: (Callable[[any, any], any] | None) = None, *, initial: any = None
) -> Iterator[any];

def _accumulate_gen[C: Iterable](
    src: C, func: (Callable[[any, any], any] | None), initial: any
) -> Iterator[any];

def _accumulate_default[C: Iterable](src: C, initial: any) -> Iterator[any];

def _accumulate_func[C: Iterable](
    src: C, func: Callable[[any, any], any], initial: any
) -> Iterator[any];

def:pub chain(*iterables: any) -> Iterator[any];

def chain_from_iterable[C: Iterable](iterable: C) -> Iterator[any];

def _chain_fi_gen[C: Iterable](src: C) -> Iterator[any];

def:pub compress[C: Iterable, S: Iterable](data: C, selectors: S) -> Iterator[any];

def _compress_gen[C: Iterable, S: Iterable](data: C, selectors: S) -> Iterator[any];

def:pub dropwhile[C: Iterable](
    predicate: Callable[[any], any], iterable: C
) -> Iterator[any];

def _dropwhile_gen[C: Iterable](pred: Callable[[any], any], src: C) -> Iterator[any];

def:pub takewhile[C: Iterable](
    predicate: Callable[[any], any], iterable: C
) -> Iterator[any];

def _takewhile_gen[C: Iterable](pred: Callable[[any], any], src: C) -> Iterator[any];

def:pub filterfalse[C: Iterable](
    predicate: (Callable[[any], any] | None), iterable: C
) -> Iterator[any];

def _filterfalse_gen[C: Iterable](
    pred: (Callable[[any], any] | None), src: C
) -> Iterator[any];

def _ff_none[C: Iterable](src: C) -> Iterator[any];

def _ff_pred[C: Iterable](src: C, pred: Callable[[any], any]) -> Iterator[any];

def:pub groupby[C: Iterable](
    iterable: C, key: (Callable[[any], any] | None) = None
) -> Iterator[any];

def _groupby_gen[C: Iterable](
    src: C, key: (Callable[[any], any] | None)
) -> Iterator[any];

def _grouped_nokey[C: Iterable](src: C) -> Iterator[any];

def _grouped_key[C: Iterable](src: C, key: Callable[[any], any]) -> Iterator[any];

def:pub islice[C: Iterable](iterable: C, *args: any) -> Iterator[any];

def _islice_gen[C: Iterable](
    src: C, start: int, stop: int, step: int
) -> Iterator[any];

def:pub pairwise[C: Iterable](iterable: C) -> Iterator[any];

def _pairwise_gen[C: Iterable](src: C) -> Iterator[any];

def:pub starmap[C: Iterable](
    func: Callable[[any, any], any], iterable: C
) -> Iterator[any];

def _starmap_gen[C: Iterable](
    func: Callable[[any, any], any], src: C
) -> Iterator[any];

def:pub product(*iterables: any, repeat: int = 1) -> Iterator[any];

def _product_gen(pools: list[list[any]]) -> Iterator[any];

def:pub permutations[C: Iterable](iterable: C, r: int | None = None) -> Iterator[any];

def _perm_gen(pool: list[any], r: int) -> Iterator[any];

def:pub combinations[C: Iterable](iterable: C, r: int) -> Iterator[any];

def _comb_gen(pool: list[any], r: int) -> Iterator[any];

def:pub combinations_with_replacement[C: Iterable](
    iterable: C, r: int
) -> Iterator[any];

def _cwr_gen(pool: list[any], r: int) -> Iterator[any];

def:pub batched[C: Iterable](
    iterable: C, n: int, *, strict: bool = False
) -> Iterator[any];

def _batched_gen[C: Iterable](src: C, n: int, strict: bool) -> Iterator[any];

def:pub zip_longest(*iterables: any, fillvalue: any = None) -> Iterator[any];

def _zip_longest_gen(pools: list[list[any]], fillvalue: any) -> Iterator[any];

def:pub tee[C: Iterable](iterable: C, n: int = 2) -> list[any];
