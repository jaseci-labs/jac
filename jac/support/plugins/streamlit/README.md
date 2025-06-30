# jaclang_streamlit Plugin Documentation

The `jaclang_streamlit` plugin is a powerful tool that allows you to run and test Streamlit apps written in Jac. This documentation will guide you through the installation process and provide instructions on how to run and test your Jac Streamlit apps.

## Installation

To install the `jaclang_streamlit` plugin, you can use pip:

```shell
pip install jaclang_streamlit
```

## Running Jac Streamlit Apps

To run a Streamlit app written in Jac, you can use the following command:

```shell
jac streamlit app.jac
```

Replace `app.jac` with the path to your Jac Streamlit app file.

## Generating Graphs with Jac Streamlit

If you want to visualize the graph of your Jac Streamlit app in a browser, you can use the following command:

```shell
jac dot_view app.jac
```

This will open up a Streamlit app in your browser, displaying the graph of your Jac Streamlit app.

## Testing Jac Streamlit Apps

To test your Jac Streamlit app using the Streamlit testing framework, you can follow these steps:

1. Import the `AppTest` class from `jaclang_streamlit`:

```python
from jaclang_streamlit import AppTest
```

2. Use the `AppTest.from_jac_file(filename)` method to create an instance of `AppTest` for your Jac Streamlit app:

```python
app_test = AppTest.from_jac_file(filename)
```

Replace `filename` with the path to your Jac Streamlit app file.

3. You can now use the `app_test` instance to test your Jac Streamlit app using the Streamlit testing methodology.

Please note that the testing methodology for Jac Streamlit apps is similar to the one used for regular Streamlit apps.
