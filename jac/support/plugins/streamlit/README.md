# Jac-Streamlit Plugin

The `jac-streamlit` plugin provides seamless integration between the Jac programming language and Streamlit, enabling you to create interactive web applications and visualizations directly from Jac code.

## Features

- **Direct Execution**: Run Streamlit apps written in Jac with a single command
- **Graph Visualization**: Interactive and static visualization of Jac graph structures
- **Testing Framework**: Comprehensive testing support for Jac-Streamlit applications
- **Cross-Platform**: Works on Windows, macOS, and Linux

## Installation

```shell
pip install jac-streamlit
```

## Quick Start

### Running Jac Streamlit Applications

Execute a Streamlit app written in Jac:

```shell
jac streamlit app.jac
```

### Visualizing Jac Graphs

Visualize your Jac graph structures in an interactive web interface:

```shell
jac dot_view app.jac
```

This opens a Streamlit application with two visualization modes:
- **Interactive View**: Using streamlit-agraph for dynamic graph exploration
- **Static View**: Using pygraphviz for traditional graph rendering

## Testing

The plugin includes a testing framework compatible with Streamlit's testing methodology:

```python
from jaclang_streamlit import AppTest

# Create test instance from Jac file
app_test = AppTest.from_jac_file("path/to/your/app.jac")

# Run the app and perform tests
app = app_test.run()
assert len(app.exception) == 0
```

## Example

Here's a simple Jac Streamlit application:

```jac
import streamlit as st;

with entry {
    st.title("Hello Jac Streamlit!");
    name = st.text_input("Enter your name");
    if st.button("Greet") and name {
        st.success(f"Hello, {name}!");
    }
}
```

## Requirements

- Python 3.12+
- Jac programming language (jaclang)
- Streamlit 1.38+

## Documentation

For comprehensive documentation and examples, visit [jac-lang.org](https://jac-lang.org).

## License

MIT License - see the [LICENSE](https://github.com/jaseci-labs/jaseci/blob/main/LICENSE) file for details.
