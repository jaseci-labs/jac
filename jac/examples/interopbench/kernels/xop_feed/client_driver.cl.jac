import from "@jac/runtime" { __jacCallFunction }

sv import from feed_provider { feed_checksum }


async def:pub run_feed(work: int, calls: int) -> int {
    checksum = 0;
    for call_no in range(calls) {
        part = await feed_checksum(call_no + 1, work);
        checksum = (checksum + part) % 2147483648;
    }
    return checksum;
}
