"""Test cases for parser performance during rapid typing scenarios."""
import time
import threading
import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import List

from jaclang.compiler.program import JacProgram
from jaclang.langserve.engine import JacLangServer


class TestParserPerformance:
    """Test parser performance under various conditions."""
    
    def get_sample_jac_code(self) -> str:
        """Sample Jac code for testing."""
        return """
# Jac Development Test File
# This file is for testing language server changes

node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}


with entry {
    test_node = example();
    test_node.greet();
}





node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

















 


 





with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}





with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}
node example {
    has name: str = "test";
    
    def greet {
        print(f"Hello from {self.name}!");
    }
}

with entry {
    test_node = example();
    test_node.greet();
}

"""
    
    def test_single_parse_performance(self):
        """Test single parsing operation performance."""
        sample_jac_code = self.get_sample_jac_code()
        program = JacProgram()
        
        start_time = time.time()
        module = program.compile(use_str=sample_jac_code, file_path="test.jac")
        parse_time = time.time() - start_time
        
        print(f"Single parse time: {parse_time:.4f} seconds")
        
        # Single parse should be fast (< 2 seconds)
        assert parse_time < 2.0, f"Single parse took {parse_time:.4f}s, expected < 2.0s"
        assert module is not None
        assert len(program.errors_had) == 0, f"Parse errors: {program.errors_had}"
    
    def test_concurrent_parse_performance(self):
        """Test concurrent parsing operations (simulating rapid typing)."""
        sample_jac_code = self.get_sample_jac_code()
        parse_times: List[float] = []
        errors: List[Exception] = []
        
        def parse_operation(iteration: int) -> None:
            """Single parse operation."""
            try:
                program = JacProgram()  # Separate instance per thread
                start_time = time.time()
                module = program.compile(use_str=sample_jac_code, file_path=f"test_{iteration}.jac")
                parse_time = time.time() - start_time
                parse_times.append(parse_time)
                print(f"Parse {iteration}: {parse_time:.4f} seconds")
            except Exception as e:
                errors.append(e)
        
        # Simulate rapid typing with 5 concurrent parse operations
        threads = []
        for i in range(5):
            thread = threading.Thread(target=parse_operation, args=(i,))
            threads.append(thread)
        
        # Start all threads simultaneously (simulating rapid typing)
        start_time = time.time()
        for thread in threads:
            thread.start()
        
        # Wait for all to complete
        for thread in threads:
            thread.join()
        
        total_time = time.time() - start_time
        avg_parse_time = sum(parse_times) / len(parse_times) if parse_times else 0
        max_parse_time = max(parse_times) if parse_times else 0
        
        print(f"Concurrent parsing results:")
        print(f"  Total time: {total_time:.4f} seconds")
        print(f"  Average parse time: {avg_parse_time:.4f} seconds")
        print(f"  Max parse time: {max_parse_time:.4f} seconds")
        print(f"  Parse times: {[round(t, 4) for t in parse_times]}")
        print(f"  Errors: {len(errors)}")
        
        assert len(errors) == 0, f"Parse errors occurred: {errors}"
        assert len(parse_times) == 5, f"Expected 5 parse operations, got {len(parse_times)}"
        
        # Each individual parse should still be reasonable
        assert max_parse_time < 3.0, f"Max parse time {max_parse_time:.4f}s exceeded 3.0s threshold"
        assert avg_parse_time < 2.0, f"Average parse time {avg_parse_time:.4f}s exceeded 2.0s threshold"
    
    def test_shared_jacprogram_contention(self):
        """Test the old problematic approach with shared JacProgram."""
        sample_jac_code = self.get_sample_jac_code()
        shared_program = JacProgram()
        parse_times: List[float] = []
        errors: List[Exception] = []
        
        def parse_with_shared_program(iteration: int) -> None:
            """Parse using shared JacProgram instance (old approach)."""
            try:
                start_time = time.time()
                # This should cause contention and slow parsing
                module = shared_program.compile(use_str=sample_jac_code, file_path=f"test_{iteration}.jac")
                parse_time = time.time() - start_time
                parse_times.append(parse_time)
                print(f"Shared parse {iteration}: {parse_time:.4f} seconds")
            except Exception as e:
                errors.append(e)
        
        # Run concurrent operations with shared instance
        threads = []
        for i in range(5):
            thread = threading.Thread(target=parse_with_shared_program, args=(i,))
            threads.append(thread)
        
        start_time = time.time()
        for thread in threads:
            thread.start()
        
        for thread in threads:
            thread.join()
        
        total_time = time.time() - start_time
        avg_parse_time = sum(parse_times) / len(parse_times) if parse_times else 0
        max_parse_time = max(parse_times) if parse_times else 0
        
        print(f"Shared JacProgram results:")
        print(f"  Total time: {total_time:.4f} seconds")
        print(f"  Average parse time: {avg_parse_time:.4f} seconds")
        print(f"  Max parse time: {max_parse_time:.4f} seconds")
        print(f"  Parse times: {[round(t, 4) for t in parse_times]}")
        
        # This test documents the problem - shared instances should show slower times
        if max_parse_time > 2.0:
            print(f"⚠️  Confirmed: Shared JacProgram causes slowdown (max: {max_parse_time:.4f}s)")
    
    async def test_language_server_performance(self):
        """Test our fixed JacLangServer performance."""
        sample_jac_code = self.get_sample_jac_code()
        server = JacLangServer()
        
        # Mock workspace document
        class MockDocument:
            def __init__(self, source: str, path: str):
                self.source = source
                self.path = path
                self.lines = source.splitlines()
        
        class MockWorkspace:
            def __init__(self, document: MockDocument):
                self.document = document
            
            def get_text_document(self, uri: str) -> MockDocument:
                return self.document
        
        server.workspace = MockWorkspace(MockDocument(sample_jac_code, "/tmp/test.jac"))
        
        # Test quick_check performance
        parse_times: List[float] = []
        
        async def run_quick_check(i: int) -> None:
            start_time = time.time()
            result = await server.launch_quick_check(f"file:///tmp/test_{i}.jac")
            parse_time = time.time() - start_time
            parse_times.append(parse_time)
            print(f"Quick check {i}: {parse_time:.4f} seconds, result: {result}")
        
        # Run multiple quick checks concurrently
        tasks = [run_quick_check(i) for i in range(5)]
        await asyncio.gather(*tasks)
        
        avg_time = sum(parse_times) / len(parse_times)
        max_time = max(parse_times)
        
        print(f"JacLangServer quick_check results:")
        print(f"  Average time: {avg_time:.4f} seconds")
        print(f"  Max time: {max_time:.4f} seconds")
        print(f"  Times: {[round(t, 4) for t in parse_times]}")
        
        # Our fixed version should perform better
        assert max_time < 3.0, f"Max quick check time {max_time:.4f}s exceeded 3.0s"
        assert avg_time < 2.0, f"Average quick check time {avg_time:.4f}s exceeded 2.0s"
    
    def test_parse_with_profiling(self):
        """Test parsing with detailed profiling to identify bottlenecks."""
        import cProfile
        import pstats
        import io
        
        sample_jac_code = self.get_sample_jac_code()
        
        def profile_parse():
            program = JacProgram()
            return program.compile(use_str=sample_jac_code, file_path="test.jac")
        
        # Profile the parsing operation
        profiler = cProfile.Profile()
        profiler.enable()
        
        start_time = time.time()
        module = profile_parse()
        total_time = time.time() - start_time
        
        profiler.disable()
        
        # Analyze profile results
        s = io.StringIO()
        ps = pstats.Stats(profiler, stream=s)
        ps.sort_stats('cumulative')
        ps.print_stats(20)  # Top 20 functions
        
        profile_output = s.getvalue()
        print(f"\nParsing took {total_time:.4f} seconds")
        print("Top functions by cumulative time:")
        print(profile_output)
        
        assert module is not None
        assert total_time < 2.0, f"Profiled parse took {total_time:.4f}s"


if __name__ == "__main__":
    # Run tests directly for quick debugging
    test_instance = TestParserPerformance()
    
    print("=== Running Parser Performance Tests ===")
    
    print("\n1. Single Parse Performance:")
    test_instance.test_single_parse_performance()
    
    print("\n2. Concurrent Parse Performance (Thread-Safe):")
    test_instance.test_concurrent_parse_performance()
    
    print("\n3. Shared JacProgram Contention (Old Approach):")
    test_instance.test_shared_jacprogram_contention()
    
    print("\n4. Parse Profiling:")
    test_instance.test_parse_with_profiling()
