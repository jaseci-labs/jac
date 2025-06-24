# Chapter 6: Imports System and File Operations

Jac provides a powerful module system for organizing code across multiple files and seamless integration with external systems. This chapter demonstrates building a simple configuration management system that showcases import patterns and file operations.

!!! topic "Module Organization"
    Well-organized modules make your code maintainable, reusable, and easier to test. Jac's import system supports both local modules and Python libraries.

## Import Statements and Module Organization

### Basic Import Patterns

!!! example "Basic Import Statements"
    === "Jac"
        <div class="code-block">
        ```jac
        # Import Python modules
        import os;
        import json;
        import sys;

        # Import specific functions from Python modules
        import from datetime  {datetime}
        import from pathlib {Path}

        # Import Jac modules
        # include my_module;
        # include utils.file_helper;

        with entry {
            # Use imported modules
            current_time = datetime.now();
            current_dir = os.getcwd();
            print(f"Current time: {current_time}");
            print(f"Current directory: {current_dir}");
        }
        ```
        </div>
    === "Python"
        ```python
        # Import Python modules
        import os
        import json
        import sys

        # Import specific functions
        from datetime import datetime
        from pathlib import Path

        # Import local modules
        import my_module
        from utils import file_helper

        if __name__ == "__main__":
            # Use imported modules
            current_time = datetime.now()
            current_dir = os.getcwd()
            print(f"Current time: {current_time}")
            print(f"Current directory: {current_dir}")
        ```

### Implementation Separation

!!! topic "Implementation Files"
    Jac supports separating interface definitions from implementations using `.impl.jac` files, promoting clean architecture and modularity. This separation makes it easier to test, maintain, and update implementations without changing interfaces.

!!! example "Interface and Implementation Separation"
    === "math_ops.jac"
        <div class="code-block">
        ```jac
        # Interface definition
        obj Calculator {
            has precision: int = 2;

            def add(a: float, b: float) -> float;
            def subtract(a: float, b: float) -> float;
            def multiply(a: float, b: float) -> float;
            def divide(a: float, b: float) -> float;
        }
        ```
        </div>
    === "math_ops.impl.jac"
        <div class="code-block">
        ```jac
        # Implementation file
        impl Calculator.add {
            result = a + b;
            return round(result, self.precision);
        }

        impl Calculator.subtract {
            result = a - b;
            return round(result, self.precision);
        }

        impl Calculator.multiply {
            result = a * b;
            return round(result, self.precision);
        }

        impl Calculator.divide {
            if b == 0.0 {
                raise ValueError("Division by zero");
            }
            result = a / b;
            return round(result, self.precision);
        }
        ```
        </div>
    === "Python Equivalent"
        ```python
        # Python class definition
        class Calculator:
            def __init__(self, precision: int = 2):
                self.precision = precision

            def add(self, a: float, b: float) -> float:
                result = a + b
                return round(result, self.precision)

            def subtract(self, a: float, b: float) -> float:
                result = a - b
                return round(result, self.precision)

            def multiply(self, a: float, b: float) -> float:
                result = a * b
                return round(result, self.precision)

            def divide(self, a: float, b: float) -> float:
                if b == 0.0:
                    raise ValueError("Division by zero")
                result = a / b
                return round(result, self.precision)
        ```
### Namespace Injection
!!! topic "Namespace Injection"
    Jac provides several mechanisms to manage namespaces clearly and effectively:

    * **import**: Loads an entire Python module or package, preserving its namespace.

    ```jac
    import os;
    os.getcwd();
    ```

    * **include**: Imports all exported symbols from a Jac module directly into the current namespace, flattening it and simplifying access.

    ```jac
    include my_utils;
    utility_function();
    ```

    * **import from**: Explicitly imports selected symbols from a module, improving clarity and avoiding namespace pollution.

    ```jac
    import from datetime {datetime};
    now = datetime.now();
    ```

    * **Aliasing**: Allows renaming imported modules or symbols, helping avoid naming conflicts.

    ```jac
    import json as js;
    data = js.load(file);
    ```

### Jac Import Internals
!!! topic "Import Resolution Workflow"
    Jac resolves imports using a structured process:

    * Parses import statements to determine modules.
    * Searches for modules in the caller directory, `JAC_PATH`, and Python's `sys.path`.
    * Compiles `.jac` files to bytecode (`.jir`) if necessary.
    * Executes bytecode to populate module namespaces.
    * Caches modules to improve performance.

    Common issues include missing bytecode, syntax errors, and circular dependencies.

## File Operations and External Integration

!!! topic "File Handling"
    File operations are essential for configuration management, data processing, and system integration.

### Basic File Operations

!!! example "File Reading and Writing"
    === "Jac"
        <div class="code-block">
        ```jac
        import os;
        import json;

        # Read text file safely
        def read_file(filepath: str) -> str | None {
            try {
                with open(filepath, 'r') as file {
                    return file.read();
                }
            } except FileNotFoundError {
                print(f"File not found: {filepath}");
                return None;
            } except Exception as e {
                print(f"Error reading file: {e}");
                return None;
            }
        }

        # Write text file safely
        def write_file(filepath: str, content: str) -> bool {
            try {
                with open(filepath, 'w') as file {
                    file.write(content);
                }
                return True;
            } except Exception as e {
                print(f"Error writing file: {e}");
                return False;
            }
        }

        # Read JSON file
        def read_json(filepath: str) -> dict | None {
            try {
                with open(filepath, 'r') as file {
                    return json.load(file);
                }
            } except FileNotFoundError {
                print(f"JSON file not found: {filepath}");
                return None;
            } except json.JSONDecodeError {
                print(f"Invalid JSON in file: {filepath}");
                return None;
            }
        }

        with entry {
            # Test file operations
            test_content = "Hello from Jac!";
            if write_file("test.txt", test_content) {
                content = read_file("test.txt");
                print(f"File content: {content}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        import os
        import json
        from typing import Optional

        # Read text file safely
        def read_file(filepath: str) -> Optional[str]:
            try:
                with open(filepath, 'r') as file:
                    return file.read()
            except FileNotFoundError:
                print(f"File not found: {filepath}")
                return None
            except Exception as e:
                print(f"Error reading file: {e}")
                return None

        # Write text file safely
        def write_file(filepath: str, content: str) -> bool:
            try:
                with open(filepath, 'w') as file:
                    file.write(content)
                return True
            except Exception as e:
                print(f"Error writing file: {e}")
                return False

        # Read JSON file
        def read_json(filepath: str) -> Optional[dict]:
            try:
                with open(filepath, 'r') as file:
                    return json.load(file)
            except FileNotFoundError:
                print(f"JSON file not found: {filepath}")
                return None
            except json.JSONDecodeError:
                print(f"Invalid JSON in file: {filepath}")
                return None

        if __name__ == "__main__":
            # Test file operations
            test_content = "Hello from Python!"
            if write_file("test.txt", test_content):
                content = read_file("test.txt")
                print(f"File content: {content}")
        ```

## Complete Example: Configuration Management System

!!! topic "Multi-Module Application"
    This example demonstrates how to build a configuration system using multiple modules working together.

### Configuration Reader Module

!!! example "Configuration Reader (config_reader.jac)"
    === "Jac"
        <div class="code-block">
        ```jac
        # config_reader.jac
        import json;
        import os;
        import from pathlib { Path }

        obj ConfigReader {
            has config_file: str;
            has config_data: dict[str, any] = {};

            def load_config() -> bool;
            def get_value(key: str, default: any = None) -> any;
            def set_value(key: str, value: any) -> None;
            def save_config() -> bool;
            def create_default_config() -> None;
        }

        impl ConfigReader.load_config {
            if not os.path.exists(self.config_file) {
                print(f"Config file {self.config_file} not found, creating default");
                self.create_default_config();
                return True;
            }

            try {
                with open(self.config_file, 'r') as file {
                    self.config_data = json.load(file);
                }
                print(f"Config loaded from {self.config_file}");
                return True;
            } except json.JSONDecodeError {
                print(f"Invalid JSON in {self.config_file}");
                return False;
            } except Exception as e {
                print(f"Error loading config: {e}");
                return False;
            }
        }

        impl ConfigReader.get_value {
            return self.config_data.get(key, default);
        }

        impl ConfigReader.set_value {
            self.config_data[key] = value;
        }

        impl ConfigReader.save_config {
            try {
                with open(self.config_file, 'w') as file {
                    json.dump(self.config_data, file, indent=2);
                }
                print(f"Config saved to {self.config_file}");
                return True;
            } except Exception as e {
                print(f"Error saving config: {e}");
                return False;
            }
        }

        impl ConfigReader.create_default_config {
            self.config_data = {
                "app_name": "My Jac App",
                "version": "1.0.0",
                "debug": False,
                "database": {
                    "host": "localhost",
                    "port": 5432,
                    "name": "myapp_db"
                },
                "logging": {
                    "level": "INFO",
                    "file": "app.log"
                }
            };
            self.save_config();
        }
        ```
        </div>
    === "Python"
        ```python
        # config_reader.py
        import json
        import os
        from pathlib import Path
        from typing import Any, Dict, Optional

        class ConfigReader:
            def __init__(self, config_file: str):
                self.config_file = config_file
                self.config_data: Dict[str, Any] = {}

            def load_config(self) -> bool:
                if not os.path.exists(self.config_file):
                    print(f"Config file {self.config_file} not found, creating default")
                    self.create_default_config()
                    return True

                try:
                    with open(self.config_file, 'r') as file:
                        self.config_data = json.load(file)
                    print(f"Config loaded from {self.config_file}")
                    return True
                except json.JSONDecodeError:
                    print(f"Invalid JSON in {self.config_file}")
                    return False
                except Exception as e:
                    print(f"Error loading config: {e}")
                    return False

            def get_value(self, key: str, default: Any = None) -> Any:
                return self.config_data.get(key, default)

            def set_value(self, key: str, value: Any) -> None:
                self.config_data[key] = value

            def save_config(self) -> bool:
                try:
                    with open(self.config_file, 'w') as file:
                        json.dump(self.config_data, file, indent=2)
                    print(f"Config saved to {self.config_file}")
                    return True
                except Exception as e:
                    print(f"Error saving config: {e}")
                    return False

            def create_default_config(self) -> None:
                self.config_data = {
                    "app_name": "My Python App",
                    "version": "1.0.0",
                    "debug": False,
                    "database": {
                        "host": "localhost",
                        "port": 5432,
                        "name": "myapp_db"
                    },
                    "logging": {
                        "level": "INFO",
                        "file": "app.log"
                    }
                }
                self.save_config()
        ```

### Application Module

!!! example "Application Module (app.jac)"
    === "Jac"
        <div class="code-block">
        ```jac
        # app.jac
        # include config_reader;
        import logging;

        obj Application {
            has config: ConfigReader;
            has logger: any;

            def start() -> None;
            def setup_logging() -> None;
            def get_database_config() -> dict[str, any];
            def run_debug_mode() -> None;
            def run_normal_mode() -> None;
        }

        impl Application.start {
            print("=== Starting Application ===");

            # Load configuration
            if self.config.load_config() {
                self.setup_logging();

                # Display app info
                app_name = self.config.get_value("app_name", "Unknown App");
                version = self.config.get_value("version", "1.0.0");
                debug_mode = self.config.get_value("debug", False);

                print(f"App: {app_name} v{version}");
                print(f"Debug mode: {debug_mode}");

                # Show database config
                db_config = self.get_database_config();
                print(f"Database: {db_config['host']}:{db_config['port']}/{db_config['name']}");

                if debug_mode {
                    self.run_debug_mode();
                } else {
                    self.run_normal_mode();
                }
            } else {
                print("Failed to load configuration");
            }
        }

        impl Application.setup_logging {
            log_config = self.config.get_value("logging", {});
            log_level = log_config.get("level", "INFO");
            log_file = log_config.get("file", "app.log");

            logging.basicConfig(
                level=getattr(logging, log_level),
                format='%(asctime)s - %(levelname)s - %(message)s',
                handlers=[
                    logging.FileHandler(log_file),
                    logging.StreamHandler()
                ]
            );

            self.logger = logging.getLogger("app");
            self.logger.info("Logging configured");
        }

        impl Application.get_database_config {
            default_db = {"host": "localhost", "port": 5432, "name": "default_db"};
            return self.config.get_value("database", default_db);
        }

        impl Application.run_debug_mode {
            print(">>> Running in DEBUG mode");
            print(f">>> Full config: {self.config.config_data}");
        }

        impl Application.run_normal_mode {
            print(">>> Running in NORMAL mode");
            print(">>> Application ready");
        }
        ```
        </div>
    === "Python"
        ```python
        # app.py
        from config_reader import ConfigReader
        import logging
        from typing import Dict, Any

        class Application:
            def __init__(self, config_file: str):
                self.config = ConfigReader(config_file)
                self.logger = None

            def start(self) -> None:
                print("=== Starting Application ===")

                # Load configuration
                if self.config.load_config():
                    self.setup_logging()

                    # Display app info
                    app_name = self.config.get_value("app_name", "Unknown App")
                    version = self.config.get_value("version", "1.0.0")
                    debug_mode = self.config.get_value("debug", False)

                    print(f"App: {app_name} v{version}")
                    print(f"Debug mode: {debug_mode}")

                    # Show database config
                    db_config = self.get_database_config()
                    print(f"Database: {db_config['host']}:{db_config['port']}/{db_config['name']}")

                    if debug_mode:
                        self.run_debug_mode()
                    else:
                        self.run_normal_mode()
                else:
                    print("Failed to load configuration")

            def setup_logging(self) -> None:
                log_config = self.config.get_value("logging", {})
                log_level = log_config.get("level", "INFO")
                log_file = log_config.get("file", "app.log")

                logging.basicConfig(
                    level=getattr(logging, log_level),
                    format='%(asctime)s - %(levelname)s - %(message)s',
                    handlers=[
                        logging.FileHandler(log_file),
                        logging.StreamHandler()
                    ]
                )

                self.logger = logging.getLogger("app")
                self.logger.info("Logging configured")

            def get_database_config(self) -> Dict[str, Any]:
                default_db = {"host": "localhost", "port": 5432, "name": "default_db"}
                return self.config.get_value("database", default_db)

            def run_debug_mode(self) -> None:
                print(">>> Running in DEBUG mode")
                print(f">>> Full config: {self.config.config_data}")

            def run_normal_mode(self) -> None:
                print(">>> Running in NORMAL mode")
                print(">>> Application ready")
        ```

### Main Application Entry Point

!!! example "Main Entry Point (main.jac)"
    === "Jac"
        <div class="code-block">
        ```jac
        # main.jac
        include app;

        with entry {
            print("=== Configuration Management Demo ===");

            # Create and run application
            application = Application(config=ConfigReader(config_file="app_config.json"));
            application.start();

            print("\n=== Configuration Update Demo ===");

            # Update configuration at runtime
            application.config.set_value("debug", True);
            application.config.set_value("app_name", "Updated Jac App");
            application.config.save_config();

            # Restart with new config
            print("\nRestarting with updated configuration:");
            application.start();
        }
        ```
        </div>
    === "Python"
        ```python
        # main.py
        from app import Application

        if __name__ == "__main__":
            print("=== Configuration Management Demo ===")

            # Create and run application
            application = Application("app_config.json")
            application.start()

            print("\n=== Configuration Update Demo ===")

            # Update configuration at runtime
            application.config.set_value("debug", True)
            application.config.set_value("app_name", "Updated Python App")
            application.config.save_config()

            # Restart with new config
            print("\nRestarting with updated configuration:")
            application.start()
        ```

## Package Structure and Organization

!!! topic "Project Structure"
    Well-organized project structure makes your code maintainable and scalable.

!!! example "Recommended Project Structure"
    === "Jac Project Structure"
        ```
        my_jac_project/
        ├── main.jac                 # Main entry point
        ├── app.jac                  # Application logic
        ├── app.test.jac             # App tests
        ├── config_reader.jac        # Config management
        ├── config_reader.impl.jac   # Config implementation
        ├── config_reader.test.jac   # Config tests
        ├── utils/
        │   ├── file_utils.jac       # File utilities
        │   └── data_utils.jac       # Data processing
        ├── models/
        │   ├── user.jac             # User model
        │   └── user.impl.jac        # User implementation
        ├── docs/
        │   └── README.md            # Documentation
        └── config/
            └── app_config.json      # Configuration files
        ```
    === "Python Project Structure"
        ```
        my_python_project/
        ├── main.py                  # Main entry point
        ├── app.py                   # Application logic
        ├── config_reader.py         # Config management
        ├── utils/
        │   ├── __init__.py
        │   ├── file_utils.py        # File utilities
        │   └── data_utils.py        # Data processing
        ├── models/
        │   ├── __init__.py
        │   └── user.py              # User model
        ├── tests/
        │   ├── __init__.py
        │   ├── test_config.py       # Config tests
        │   └── test_app.py          # App tests
        ├── docs/
        │   └── README.md            # Documentation
        └── config/
            └── app_config.json      # Configuration files
        ```

## Best Practices

!!! summary "Import and File Operation Best Practices"
    - **Organize by functionality**: Group related code into logical modules
    - **Use explicit imports**: Import only what you need for clarity
    - **Handle errors gracefully**: Always use try-catch for file operations
    - **Separate interface from implementation**: Use `.impl.jac` files for complex objects
    - **Validate file inputs**: Check file existence and format before processing
    - **Use configuration files**: Externalize settings for flexibility
    - **Document your modules**: Clear documentation helps team collaboration

## Key Takeaways

!!! summary "Chapter Summary"
    - **Import System**: Jac supports both local modules and Python libraries seamlessly
    - **Implementation Separation**: `.impl.jac` files promote clean architecture
    - **File Operations**: Safe file handling with proper error management
    - **Configuration Management**: External configuration files improve flexibility
    - **Module Organization**: Well-structured projects are easier to maintain and scale
    - **Python Integration**: Leverage existing Python ecosystem alongside Jac features

In the next chapter, we'll explore Jac's unique pipe operations and AI integration features that make data processing and AI workflows much more intuitive.
