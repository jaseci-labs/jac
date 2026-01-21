# Part VI: Concurrency

## 30. Async/Await

### 30.1 Async Functions

```jac
async def fetch_data(url: str) -> dict {
    response = await http_get(url);
    return await response.json();
}

async def process_multiple(urls: list[str]) -> list[dict] {
    results = [];
    for url in urls {
        data = await fetch_data(url);
        results.append(data);
    }
    return results;
}
```

### 30.2 Async Walkers

```jac
async walker DataFetcher {
    has url: str;

    async can fetch with `root entry {
        data = await http_get(self.url);
        report data;
    }
}
```

### 30.3 Async For Loops

```jac
async def process_stream(stream: AsyncIterator) -> None {
    async for item in stream {
        print(item);
    }
}
```

---

## 31. Concurrent Expressions

### 31.1 flow Keyword

Launch computation without waiting:

```jac
future = flow expensive_computation();

# Do other work while computation runs
other_result = do_something_else();

# Wait for result when needed
result = wait future;
```

### 31.2 Parallel Operations

```jac
# Launch multiple operations in parallel
future1 = flow fetch_users();
future2 = flow fetch_orders();
future3 = flow fetch_inventory();

# Continue with other work
process_local_data();

# Collect all results
users = wait future1;
orders = wait future2;
inventory = wait future3;
```

### 31.3 flow vs async

| Feature | async/await | flow/wait |
|---------|-------------|-----------|
| Model | Event loop (cooperative) | Thread pool (parallel) |
| Best for | I/O-bound, many concurrent | CPU-bound, few concurrent |
| Blocking | Non-blocking | Can block threads |

---
