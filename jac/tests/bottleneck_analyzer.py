"""Targeted investigation of parser performance bottlenecks."""
import time
import threading
import os
import tempfile
from typing import List, Dict
from jaclang.compiler.program import JacProgram


class ParserBottleneckAnalyzer:
    """Analyze specific bottlenecks in the parser."""
    
    def get_simple_code(self) -> str:
        """Simple code that should parse quickly."""
        return '''
walker test {
    can walk with `root entry {
        print("hello");
    }
}
'''
    
    def get_complex_code(self) -> str:
        """More complex code to test scaling."""
        return '''
import:py from jaclang.core.builtin, *;

walker complex_walker {
    has data: dict = {};
    
    can walk with `root entry {
        self.data = {"start": "test"};
        spawn here ++> node::data_node(value=42);
        visit [-->];
    }
    
    can process_data with node::data_node entry {
        print(f"Processing: {here.value}");
        here.value *= 2;
        return here.value;
    }
}

node data_node {
    has value: int = 0;
    has processed: bool = false;
    
    can validate with complex_walker entry {
        if not self.processed {
            self.processed = true;
            return true;
        }
        return false;
    }
}

obj Calculator {
    has memory: list = [];
    
    can add(a: float, b: float) -> float {
        result = a + b;
        self.memory.append(result);
        return result;
    }
    
    can get_history -> list {
        return self.memory;
    }
}
'''
    
    def test_parse_times_by_complexity(self):
        """Test how complexity affects parse time."""
        simple_code = self.get_simple_code()
        complex_code = self.get_complex_code()
        
        print("=== Parse Time by Complexity ===")
        
        # Test simple code
        program = JacProgram()
        start = time.time()
        module = program.compile(use_str=simple_code, file_path="simple.jac")
        simple_time = time.time() - start
        print(f"Simple code: {simple_time:.4f}s")
        
        # Test complex code
        program = JacProgram()
        start = time.time()
        module = program.compile(use_str=complex_code, file_path="complex.jac")
        complex_time = time.time() - start
        print(f"Complex code: {complex_time:.4f}s")
        
        return simple_time, complex_time
    
    def test_file_vs_string_parsing(self):
        """Test if file I/O is causing issues."""
        code = self.get_simple_code()
        
        print("\n=== File vs String Parsing ===")
        
        # Test string parsing
        program = JacProgram()
        start = time.time()
        module = program.compile(use_str=code, file_path="memory.jac")
        string_time = time.time() - start
        print(f"String parsing: {string_time:.4f}s")
        
        # Test file parsing
        with tempfile.NamedTemporaryFile(mode='w', suffix='.jac', delete=False) as f:
            f.write(code)
            temp_file = f.name
        
        try:
            program = JacProgram()
            start = time.time()
            module = program.compile(file_path=temp_file)
            file_time = time.time() - start
            print(f"File parsing: {file_time:.4f}s")
        finally:
            os.unlink(temp_file)
        
        return string_time, file_time
    
    def test_sequential_vs_concurrent(self):
        """Compare sequential vs concurrent parsing with detailed timing."""
        code = self.get_simple_code()
        num_operations = 5
        
        print(f"\n=== Sequential vs Concurrent ({num_operations} operations) ===")
        
        # Sequential parsing
        sequential_times = []
        total_start = time.time()
        for i in range(num_operations):
            program = JacProgram()
            start = time.time()
            module = program.compile(use_str=code, file_path=f"seq_{i}.jac")
            parse_time = time.time() - start
            sequential_times.append(parse_time)
            print(f"Sequential {i}: {parse_time:.4f}s")
        
        sequential_total = time.time() - total_start
        
        # Concurrent parsing
        concurrent_times = []
        errors = []
        
        def parse_concurrent(iteration: int):
            try:
                program = JacProgram()
                start = time.time()
                module = program.compile(use_str=code, file_path=f"conc_{iteration}.jac")
                parse_time = time.time() - start
                concurrent_times.append(parse_time)
                print(f"Concurrent {iteration}: {parse_time:.4f}s")
            except Exception as e:
                errors.append(e)
        
        threads = []
        concurrent_start = time.time()
        for i in range(num_operations):
            thread = threading.Thread(target=parse_concurrent, args=(i,))
            threads.append(thread)
            thread.start()
        
        for thread in threads:
            thread.join()
        
        concurrent_total = time.time() - concurrent_start
        
        print(f"\nResults:")
        print(f"  Sequential total: {sequential_total:.4f}s")
        print(f"  Sequential avg: {sum(sequential_times)/len(sequential_times):.4f}s")
        print(f"  Sequential times: {[round(t, 4) for t in sequential_times]}")
        print(f"  Concurrent total: {concurrent_total:.4f}s")
        print(f"  Concurrent avg: {sum(concurrent_times)/len(concurrent_times):.4f}s")
        print(f"  Concurrent times: {[round(t, 4) for t in concurrent_times]}")
        print(f"  Errors: {len(errors)}")
        
        return sequential_times, concurrent_times
    
    def test_import_resolution_impact(self):
        """Test if import resolution is the bottleneck."""
        print("\n=== Import Resolution Impact ===")
        
        # Code without imports
        no_imports = '''
walker simple {
    can walk with `root entry {
        print("test");
    }
}
'''
        
        # Code with imports
        with_imports = '''
import:py from jaclang.core.builtin, *;
import:py from os, path;
import:py from json, dumps, loads;

walker simple {
    can walk with `root entry {
        print("test");
        result = dumps({"test": "data"});
    }
}
'''
        
        # Test no imports
        program = JacProgram()
        start = time.time()
        module = program.compile(use_str=no_imports, file_path="no_imports.jac")
        no_import_time = time.time() - start
        print(f"No imports: {no_import_time:.4f}s")
        
        # Test with imports
        program = JacProgram()
        start = time.time()
        module = program.compile(use_str=with_imports, file_path="with_imports.jac")
        import_time = time.time() - start
        print(f"With imports: {import_time:.4f}s")
        
        return no_import_time, import_time
    
    def test_global_state_contention(self):
        """Test if global state is causing contention."""
        print("\n=== Global State Contention Test ===")
        
        code = self.get_simple_code()
        
        def parse_with_delay(delay: float, iteration: int) -> float:
            time.sleep(delay)  # Offset start times
            program = JacProgram()
            start = time.time()
            module = program.compile(use_str=code, file_path=f"delayed_{iteration}.jac")
            return time.time() - start
        
        # Test with staggered starts
        staggered_times = []
        threads = []
        
        for i in range(3):
            thread = threading.Thread(
                target=lambda d, it: staggered_times.append(parse_with_delay(d, it)),
                args=(i * 0.1, i)
            )
            threads.append(thread)
        
        start_time = time.time()
        for thread in threads:
            thread.start()
        
        for thread in threads:
            thread.join()
        
        total_time = time.time() - start_time
        
        print(f"Staggered parsing:")
        print(f"  Total time: {total_time:.4f}s")
        print(f"  Individual times: {[round(t, 4) for t in staggered_times]}")
        
        return staggered_times


def main():
    """Run all bottleneck analysis tests."""
    analyzer = ParserBottleneckAnalyzer()
    
    print("🔍 PARSER BOTTLENECK ANALYSIS")
    print("=" * 50)
    
    try:
        # Test 1: Complexity impact
        simple_time, complex_time = analyzer.test_parse_times_by_complexity()
        
        # Test 2: File vs string
        string_time, file_time = analyzer.test_file_vs_string_parsing()
        
        # Test 3: Sequential vs concurrent
        seq_times, conc_times = analyzer.test_sequential_vs_concurrent()
        
        # Test 4: Import resolution
        no_import_time, import_time = analyzer.test_import_resolution_impact()
        
        # Test 5: Global state contention
        staggered_times = analyzer.test_global_state_contention()
        
        print("\n" + "=" * 50)
        print("🎯 ANALYSIS SUMMARY:")
        print(f"  Complexity impact: {complex_time/simple_time:.2f}x slower for complex code")
        print(f"  File vs string: {file_time/string_time:.2f}x difference")
        print(f"  Import overhead: {import_time/no_import_time:.2f}x slower with imports")
        
        seq_avg = sum(seq_times) / len(seq_times)
        conc_avg = sum(conc_times) / len(conc_times)
        print(f"  Concurrent slowdown: {conc_avg/seq_avg:.2f}x slower when concurrent")
        
        # Identify likely bottlenecks
        print("\n🚨 LIKELY BOTTLENECKS:")
        if conc_avg > seq_avg * 2:
            print("  - Thread contention/resource locking")
        if import_time > no_import_time * 2:
            print("  - Import resolution overhead")
        if file_time > string_time * 1.5:
            print("  - File I/O bottleneck")
            
    except Exception as e:
        print(f"Error during analysis: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
