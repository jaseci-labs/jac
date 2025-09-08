"""Targeted investigation of parser bottlenecks during concurrent operations."""
import time
import threading
import cProfile
import pstats
import io
from typing import List, Dict
from concurrent.futures import ThreadPoolExecutor, as_completed

from jaclang.compiler.program import JacProgram


class ParserBottleneckInvestigation:
    """Investigate specific bottlenecks in parser performance."""
    
    def __init__(self):
        self.simple_code = """
walker test {
    can walk with `root entry {
        print("Hello");
    }
}
"""
        
        self.medium_code = """
walker complex_walker {
    can walk with `root entry {
        print("Starting complex walk");
        # spawn here ++> node::data_node;
        here ++> data_node();
    }
    
    can process with data_node entry {
        print(f"Processing: {here.value}");
        return here.value * 2;
    }
}

node data_node {
    has value: int = 42;
    has name: str = "test";
    
    def calculate(factor: int) -> int {
        return self.value * factor;
    }
}

obj Calculator {
    has result: float = 0.0;
    
    def add(val: float) {
        self.result += val;
    }
}
"""
        
        # Large realistic code that might cause issues
        self.large_code = """

walker data_processor {
    can walk with `root entry {
        print("Starting data processing");
        here ++> processor_node();

        for i in range(10) {
            here ++> data_item(value=i);
        }
    }
    
    can process_all with processor_node entry {
        items = here.get_connected_nodes();
        total = 0;
        for item in items {
            total += item.process_value();
        }
        print(f"Total processed: {total}");
        return total;
    }
}

node processor_node {
    has results: list[int] = [];
    
    def get_connected_nodes() -> list {
        return []; # simplified
    }
    
    def aggregate_results() -> int {
        return sum(self.results);
    }
}

node data_item {
    has value: int = 0;
    has processed: bool = false;
    
    def process_value() -> int {
        if not self.processed {
            self.processed = true;
            return self.value * 2;
        }
        return 0;
    }
    
    def reset() {
        self.processed = false;
        self.value = 0;
    }
}

obj DatabaseManager {
    has connections: dict = {};
    has max_connections: int = 10;
    
    def connect(name: str) -> bool {
        if len(self.connections) < self.max_connections {
            self.connections[name] = true;
            return true;
        }
        return false;
    }
    
    def disconnect(name: str) {
        if name in self.connections {
            del self.connections[name];
        }
    }
    
    def get_connection_count() -> int {
        return len(self.connections);
    }
}

walker performance_tester {
    can walk with `root entry {
        db = DatabaseManager();
        
        for i in range(5) {
            db.connect(f"conn_{i}");
        }
        
        print(f"Connections: {db.get_connection_count()}");
        
        # spawn here ++> node::test_node;
    }
}

node test_node {
    has data: list[int] = [1, 2, 3, 4, 5];
    
    def compute_stats() -> dict {
        return {
            "sum": sum(self.data),
            "length": len(self.data),
            "average": sum(self.data) / len(self.data)
        };
    }
}

with entry {
    tester = performance_tester();
    tester.walk();
}
"""
    
    def test_sequential_vs_concurrent(self) -> None:
        """Compare sequential vs concurrent parsing performance."""
        print("=== Sequential vs Concurrent Parsing Comparison ===")
        
        # Test 1: Sequential parsing
        print("\n1. Sequential Parsing (5 operations):")
        sequential_times = []
        
        start_time = time.time()
        for i in range(5):
            program = JacProgram()
            parse_start = time.time()
            program.compile(use_str=self.large_code, file_path=f"sequential_{i}.jac")
            parse_time = time.time() - parse_start
            sequential_times.append(parse_time)
            print(f"  Parse {i}: {parse_time:.4f}s")
        
        sequential_total = time.time() - start_time
        sequential_avg = sum(sequential_times) / len(sequential_times)
        
        print(f"Sequential Results:")
        print(f"  Total time: {sequential_total:.4f}s")
        print(f"  Average per parse: {sequential_avg:.4f}s")
        print(f"  Times: {[round(t, 4) for t in sequential_times]}")
        
        # Test 2: Concurrent parsing
        print("\n2. Concurrent Parsing (5 operations):")
        concurrent_times = []
        errors = []
        
        def concurrent_parse(iteration: int) -> float:
            try:
                program = JacProgram()
                parse_start = time.time()
                program.compile(use_str=self.large_code, file_path=f"concurrent_{iteration}.jac")
                parse_time = time.time() - parse_start
                print(f"  Parse {iteration}: {parse_time:.4f}s")
                return parse_time
            except Exception as e:
                errors.append(e)
                return float('inf')
        
        # Use ThreadPoolExecutor for concurrent execution
        start_time = time.time()
        with ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(concurrent_parse, i) for i in range(5)]
            concurrent_times = [future.result() for future in as_completed(futures)]
        
        concurrent_total = time.time() - start_time
        concurrent_avg = sum(concurrent_times) / len(concurrent_times)
        concurrent_max = max(concurrent_times)
        
        print(f"Concurrent Results:")
        print(f"  Total time: {concurrent_total:.4f}s")
        print(f"  Average per parse: {concurrent_avg:.4f}s")
        print(f"  Max parse time: {concurrent_max:.4f}s")
        print(f"  Times: {[round(t, 4) for t in sorted(concurrent_times)]}")
        print(f"  Errors: {len(errors)}")
        
        # Analysis
        slowdown_factor = concurrent_avg / sequential_avg if sequential_avg > 0 else 0
        print(f"\n📊 Analysis:")
        print(f"  Slowdown factor: {slowdown_factor:.2f}x")
        print(f"  Sequential avg: {sequential_avg:.4f}s")
        print(f"  Concurrent avg: {concurrent_avg:.4f}s")
        
        if slowdown_factor > 2.0:
            print(f"  ⚠️  CRITICAL: {slowdown_factor:.1f}x slowdown during concurrent parsing!")
        elif slowdown_factor > 1.5:
            print(f"  ⚠️  WARNING: {slowdown_factor:.1f}x slowdown during concurrent parsing")
        else:
            print(f"  ✅ Acceptable performance difference")
    
    def test_profile_bottlenecks(self) -> None:
        """Profile parsing to identify specific bottlenecks."""
        print("\n=== Profiling Parser Bottlenecks ===")
        
        def profile_single_parse():
            program = JacProgram()
            return program.compile(use_str=self.large_code, file_path="profile_test.jac")
        
        def profile_concurrent_parse():
            """Profile concurrent parsing operations."""
            def parse_operation(i):
                program = JacProgram()
                return program.compile(use_str=self.large_code, file_path=f"profile_concurrent_{i}.jac")
            
            threads = []
            for i in range(3):
                thread = threading.Thread(target=parse_operation, args=(i,))
                threads.append(thread)
            
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
        
        # Profile single parse
        print("\n1. Single Parse Profile:")
        profiler = cProfile.Profile()
        profiler.enable()
        
        start_time = time.time()
        profile_single_parse()
        single_time = time.time() - start_time
        
        profiler.disable()
        
        s = io.StringIO()
        ps = pstats.Stats(profiler, stream=s)
        ps.sort_stats('cumulative')
        ps.print_stats(15)
        
        print(f"Single parse time: {single_time:.4f}s")
        print("Top functions by cumulative time:")
        print(s.getvalue())
        
        # Profile concurrent parse
        print("\n2. Concurrent Parse Profile:")
        profiler2 = cProfile.Profile()
        profiler2.enable()
        
        start_time = time.time()
        profile_concurrent_parse()
        concurrent_time = time.time() - start_time
        
        profiler2.disable()
        
        s2 = io.StringIO()
        ps2 = pstats.Stats(profiler2, stream=s2)
        ps2.sort_stats('cumulative')
        ps2.print_stats(15)
        
        print(f"Concurrent parse time: {concurrent_time:.4f}s")
        print("Top functions by cumulative time:")
        print(s2.getvalue())
    
    def test_import_resolution_impact(self) -> None:
        """Test if import resolution is causing the slowdown."""
        print("\n=== Import Resolution Impact Test ===")
        
        # Code with no imports
        simple_code = """
node simple {
    has value: int = 42;
}
"""
        
        # Code that might trigger imports
        import_code = """
import:py from builtins, print;

walker test {
    can walk with `root entry {
        print("Testing imports");
    }
}
"""
        
        def test_code_type(code: str, name: str) -> List[float]:
            times = []
            
            def parse_op(i):
                program = JacProgram()
                start = time.time()
                program.compile(use_str=code, file_path=f"{name}_{i}.jac")
                times.append(time.time() - start)
            
            threads = []
            for i in range(3):
                thread = threading.Thread(target=parse_op, args=(i,))
                threads.append(thread)
            
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            
            return times
        
        # Test simple code
        simple_times = test_code_type(simple_code, "simple")
        simple_avg = sum(simple_times) / len(simple_times)
        
        # Test import code
        import_times = test_code_type(import_code, "import")
        import_avg = sum(import_times) / len(import_times)
        
        print(f"Simple code concurrent avg: {simple_avg:.4f}s")
        print(f"Import code concurrent avg: {import_avg:.4f}s")
        print(f"Import slowdown factor: {import_avg / simple_avg:.2f}x")
        
        if import_avg > simple_avg * 2:
            print("⚠️  Import resolution likely causing slowdown")
        else:
            print("✅ Import resolution not the main bottleneck")
    
    def test_file_io_impact(self) -> None:
        """Test if file I/O is causing contention."""
        print("\n=== File I/O Impact Test ===")
        
        def parse_with_unique_paths():
            """Parse with unique file paths to avoid path conflicts."""
            times = []
            
            def parse_op(i):
                program = JacProgram()
                start = time.time()
                # Use completely unique paths
                program.compile(use_str=self.simple_code, file_path=f"/tmp/unique_test_{threading.current_thread().ident}_{i}.jac")
                times.append(time.time() - start)
            
            threads = []
            for i in range(3):
                thread = threading.Thread(target=parse_op, args=(i,))
                threads.append(thread)
            
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            
            return times
        
        def parse_with_same_paths():
            """Parse with same file paths to test path conflicts."""
            times = []
            
            def parse_op(i):
                program = JacProgram()
                start = time.time()
                # Use same path for all threads
                program.compile(use_str=self.simple_code, file_path="same_test.jac")
                times.append(time.time() - start)
            
            threads = []
            for i in range(3):
                thread = threading.Thread(target=parse_op, args=(i,))
                threads.append(thread)
            
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            
            return times
        
        unique_times = parse_with_unique_paths()
        same_times = parse_with_same_paths()
        
        unique_avg = sum(unique_times) / len(unique_times)
        same_avg = sum(same_times) / len(same_times)
        
        print(f"Unique paths avg: {unique_avg:.4f}s")
        print(f"Same paths avg: {same_avg:.4f}s")
        print(f"Path conflict factor: {same_avg / unique_avg:.2f}x")
        
        if same_avg > unique_avg * 1.5:
            print("⚠️  File path conflicts causing slowdown")
        else:
            print("✅ File paths not the main bottleneck")


def main():
    """Run the bottleneck investigation."""
    investigator = ParserBottleneckInvestigation()
    
    print("🔍 Parser Bottleneck Investigation")
    print("=" * 50)
    
    # Run all tests
    investigator.test_sequential_vs_concurrent()
    investigator.test_import_resolution_impact()
    investigator.test_file_io_impact()
    investigator.test_profile_bottlenecks()


if __name__ == "__main__":
    main()
