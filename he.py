import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

URL = "https://jac-builder.jaseci.org/"  # change endpoint if needed
MAX_WORKERS = 50  # max concurrent users
STEP = 10  # increase users per iteration
MAX_ITER = 20  # how many rounds
FAIL_THRESHOLD = 0.3  # 30% failure = break

TIMEOUT = 5


def make_request():
    try:
        start = time.time()
        response = requests.get(URL, timeout=TIMEOUT)
        latency = time.time() - start

        if response.status_code == 200:
            return True, latency
        return False, latency

    except Exception:
        return False, None


def run_test(concurrent_users):
    success = 0
    failure = 0
    latencies = []

    with ThreadPoolExecutor(max_workers=concurrent_users) as executor:
        futures = [executor.submit(make_request) for _ in range(concurrent_users)]

        for future in as_completed(futures):
            ok, latency = future.result()
            if ok:
                success += 1
                latencies.append(latency)
            else:
                failure += 1

    avg_latency = sum(latencies) / len(latencies) if latencies else 0

    return success, failure, avg_latency


def main():
    print("Starting Load Test...\n")

    for i in range(1, MAX_ITER + 1):
        users = i * STEP

        print(f"\n🚀 Testing with {users} concurrent users...")

        success, failure, avg_latency = run_test(users)

        total = success + failure
        fail_rate = failure / total if total else 0

        print(f"✅ Success: {success}")
        print(f"❌ Failure: {failure}")
        print(f"📊 Fail Rate: {fail_rate:.2%}")
        print(f"⏱ Avg Latency: {avg_latency:.2f}s")

        if fail_rate > FAIL_THRESHOLD:
            print("\n💥 Breaking point reached!")
            print(f"System starts failing at ~{users} concurrent users")
            break

        time.sleep(2)


if __name__ == "__main__":
    main()
