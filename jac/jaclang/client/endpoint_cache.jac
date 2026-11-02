def:pub __getEndpointEffects -> dict[str, any];

def:pub __getCacheState -> dict[str, any];

def:pub __isFresh(`entry: dict[str, any]) -> bool;

def:pub __cacheGet(key: str) -> dict[str, any] | None;

def:pub __cacheSet(key: str, data: any, ttl: int);

def:pub __evictOldest;

def:pub __overlaps(list1: list[str], list2: list[str]) -> bool;

def:pub __invalidateEndpoint(endpoint_key: str);

async def:pub __cachedEndpointCall(
    endpoint_key: str, args_key: str, fetch_fn: any
) -> any;

def:pub __invalidateEffects(writes: list[str]);

def:pub __jacClearCache;


def:pub __endpointKey(kind: str, name: str, opts: dict[str, any] | None) -> str;
