# Chapter 6: Imports System and File Operations

As your projects grow beyond a single file, keeping your code organized becomes essential for maintainability and collaboration. A well-structured project is easier to understand, test, and scale. This chapter introduces Jac's module system for organizing code across multiple files and its familiar approach to file operations.

You will learn how to import your own code, leverage the vast Python ecosystem, and use Jac's powerful interface-implementation pattern to build clean, robust applications.

!!! topic "Module Organization Philosophy"
    Jac's import system is your primary tool for structuring code. It allows you to define objects, nodes, walkers, and functions in separate files and use them wherever they are needed. Jac seamlessly integrates with the Python ecosystem, allowing you to import and use Python libraries directly.

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

Jac encourages a clean architectural pattern that separates what a component does from how it does it. This is achieved by splitting an object's or node's definition (its interface) from its method logic (its implementation).

The interface is defined in a `.jac` file, while the implementation is placed in a corresponding .`impl.jac` file. When you import the object, Jac automatically links them together.

!!! topic "Benefits of Separation"
    This pattern makes your code significantly more maintainable. You can change the internal logic of a method in the `.impl.jac` file without ever touching the files that use the object. It also makes testing easier, as you can mock implementations while testing against a stable interface.

!!! example "Interface and Implementation Separation"
    === "math_ops.jac"

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
    * Compiles `.jac` files to bytecode if necessary.
    * Executes bytecode to populate module namespaces.
    * Caches compiled bytecode (`.jbc` files) to improve performance.

    Common issues include syntax errors and circular dependencies.

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

!!! summary "What We've Learned"
    **Import System:**

    - **Python integration**: Seamless access to Python modules and libraries
    - **Namespace management**: Clear control over imported symbols and namespaces
    - **Aliasing support**: Rename imports to avoid conflicts and improve readability
    - **Selective imports**: Import specific functions and classes for better organization

    **Module Organization:**

    - **Implementation separation**: `.impl.jac` files promote clean architecture
    - **Interface definitions**: Clear separation between public interfaces and implementations
    - **Namespace injection**: Various mechanisms for managing symbol visibility
    - **Dependency management**: Structured approach to module dependencies

    **File Operations:**

    - **Safe file handling**: Robust error handling for file operations
    - **JSON processing**: Built-in support for configuration and data files
    - **Path management**: Integration with Python's pathlib for file system operations
    - **Configuration management**: External configuration files for application flexibility

    **Project Structure:**

    - **Modular design**: Logical organization of code into focused modules
    - **Testing integration**: Built-in support for test files alongside implementation
    - **Documentation**: Clear structure for maintaining project documentation
    - **Scalability**: Structure that grows with project complexity

!!! tip "Try It Yourself"
    Build a modular application by:
    - Creating a multi-file configuration system
    - Implementing interface/implementation separation
    - Setting up a proper project structure
    - Adding error handling for file operations

    Remember: Well-organized modules make your code maintainable and scalable!

---

*Your code is now well-organized and modular. Let's enhance it further with Jac's powerful object-oriented features!*
