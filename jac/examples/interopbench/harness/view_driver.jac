"""Drive the full-native iop_view producer through its public wrappers."""

import importlib;
import sys;
import time;
import from pathlib { Path }
import from jaclang.jac0core.native_accel { accelerate_module }
import from jaclang.jac0core.native_marshal { NativeListView, NativeStructView }


glob MODULUS: int = 2147483647,
     PRODUCER_MODNAME: str = "jac.examples.interopbench.kernels.iop_view",
     PRODUCER_PATH: str = str(
         Path(str(__file__)).resolve().parent.parent / "kernels" / "iop_view.na.jac"
     ),
     REPO_ROOT: str = str(Path(str(__file__)).resolve().parents[4]);


"""Checksum native list and struct views without materialising them."""
def checksum_views(values: NativeListView, samples: NativeListView) -> int {
    checksum = 17;
    for i in range(len(values)) {
        checksum = (checksum * 1000003 + int(values[i])) % MODULUS;
        sample = samples[i];
        if not isinstance(sample, NativeStructView) {
            raise TypeError(f"expected NativeStructView, got {type(sample)}");
        }
        checksum = (checksum * 1000003 + int(sample["value"])) % MODULUS;
        checksum = (checksum * 1000003 + int(sample["weight"])) % MODULUS;
    }
    return checksum;
}


"""Copy the native views into ordinary Python-owned Jac values."""
def materialise(
    values: NativeListView, samples: NativeListView
) -> tuple[list[int], list[tuple[int, int]]] {
    value_copy: list[int] = [];
    sample_copy: list[tuple[int, int]] = [];
    for i in range(len(values)) {
        value_copy.append(int(values[i]));
        sample = samples[i];
        if not isinstance(sample, NativeStructView) {
            raise TypeError(f"expected NativeStructView, got {type(sample)}");
        }
        sample_copy.append((int(sample["value"]), int(sample["weight"])));
    }
    return (value_copy, sample_copy);
}


"""Checksum the explicitly materialised reference values."""
def checksum_materialised(values: list[int], samples: list[tuple[int, int]]) -> int {
    checksum = 17;
    for i in range(len(values)) {
        checksum = (checksum * 1000003 + values[i]) % MODULUS;
        checksum = (checksum * 1000003 + samples[i][0]) % MODULUS;
        checksum = (checksum * 1000003 + samples[i][1]) % MODULUS;
    }
    return checksum;
}


"""Load the producer so its native wrappers are installed before timing."""
def load_producer -> any {
    if REPO_ROOT not in sys.path {
        sys.path.insert(0, REPO_ROOT);
    }
    producer = importlib.import_module(PRODUCER_MODNAME);
    _ = accelerate_module(PRODUCER_MODNAME, PRODUCER_PATH);
    return producer;
}


"""Run one view/materialised differential invocation."""
def main(argv: list[str]) {
    if len(argv) != 3 {
        raise ValueError("usage: view_driver.jac <materialised|view> <count>");
    }
    variant = argv[1];
    if variant not in ("materialised", "view") {
        raise ValueError(f"unknown variant: {variant}");
    }
    count = int(argv[2]);
    if count < 0 {
        raise ValueError("count must be non-negative");
    }

    producer = load_producer();
    _ = producer.produce_views(1);
    raw = producer.produce_views(count);
    values = raw[0] as NativeListView;
    samples = raw[1] as NativeListView;
    if not isinstance(values, NativeListView)
    or not isinstance(samples, NativeListView) {
        raise TypeError(
            f"expected NativeListView pair, got {type(values)} and {type(samples)}"
        );
    }

    started = time.perf_counter_ns();
    view_started = time.perf_counter_ns();
    view_checksum = checksum_views(values, samples);
    view_ns = time.perf_counter_ns() - view_started;

    materialise_started = time.perf_counter_ns();
    (value_copy, sample_copy) = materialise(values, samples);
    materialised_checksum = checksum_materialised(value_copy, sample_copy);
    materialise_ns = time.perf_counter_ns() - materialise_started;
    elapsed = time.perf_counter_ns() - started;

    if view_checksum != materialised_checksum {
        raise ValueError(
            "view/materialised checksum mismatch: "
            f"{view_checksum} != {materialised_checksum}"
        );
    }
    selected = materialised_checksum if variant == "materialised" else view_checksum;
    print(f"view:{selected}");
    print(f"m:view_ns={view_ns}");
    print(f"m:materialise_ns={materialise_ns}");
    print(f"ns={elapsed}");
}


with entry {
    main(sys.argv);
}
