"""Unit test utilities for JacLangServer."""

import os
import tempfile

from jaclang.vendor.pygls.uris import from_fs_path
from jaclang.vendor.pygls.workspace import Workspace

from textwrap import dedent


def get_jac_file_path():
    """Return the absolute path to the sample Jac file used for testing."""
    return os.path.abspath(
        os.path.join(
            os.path.dirname(__file__), "../../../../examples/manual_code/circle.jac"
        )
    )


def create_temp_jac_file(initial_content: str = "") -> str:
    """Create a temporary Jac file with optional initial content and return its path."""
    temp = tempfile.NamedTemporaryFile(
        delete=False, suffix=".jac", mode="w", encoding="utf-8"
    )
    temp.write(initial_content)
    temp.close()
    return temp.name


def get_code(code: str) -> str:
    """Generate a sample Jac code snippet with optional test code injected."""
    jac_code = dedent(
        f'''
    """
    This module demonstrates a simple circle class and a function to calculate
    the area of a circle in all of Jac's glory.
    """

    import math;

    # Module-level global variable
    glob RAD = 5;

    """Function to calculate the area of a circle."""
    def calculate_area(radius: float) -> float {{
        return math.pi * radius * radius;
    }}

    #* (This is a multiline comment in Jac)
    Above we have the demonstration of a function to calculate the area of a circle.
    Below we have the demonstration of a class to calculate the area of a circle.
    *#

    """Enum for shape types"""
    enum ShapeType {{
        CIRCLE = "Circle",
        UNKNOWN = "Unknown"
    }}

    """Base class for a shape."""
    obj Shape {{
        has shape_type: ShapeType;

        """Abstract method to calculate the area of a shape."""
        def area -> float abs;
    }}

    """Circle class inherits from Shape."""
    obj Circle(Shape) {{
        def init(radius: float) {{
            super.init(ShapeType.CIRCLE);
            self.radius = radius;
        }}

        """Overridden method to calculate the area of the circle."""
        override def area -> float {{
            return math.pi * self.radius * self.radius;
        }}
    }}

    with entry {{
        c = Circle(RAD);
    }}

    # Global also works here

    with entry:__main__ {{
        # To run the program functionality
        print(
            f"Area of a circle with radius {{RAD}} using function: {{calculate_area(RAD)}}"
        );
        print(
            f"Area of a {{c.shape_type.value}} with radius {{RAD}} using class: {{c.area()}}"
        );
    }}

    # Unit Tests!
    glob expected_area = 78.53981633974483;
    {code}

    test calc_area {{
        check almostEqual(calculate_area(RAD), expected_area);
    }}

    test circle_area {{
        c = Circle(RAD);
        check almostEqual(c.area(), expected_area);
    }}

    test circle_type {{
        c = Circle(RAD);
        check c.shape_type == ShapeType.CIRCLE;
    }}
'''
    )
    return jac_code


def get_simple_code(code: str) -> str:
    """Generate a sample Jac code snippet with optional test code injected."""
    jac_code = dedent(
        f"""
    
    # Unit Tests!
    glob expected_area0 = 78.53981633974483;
    glob expected_area1 = 78.53981633974483;
    {code}
    glob expected_area2 = 78.53981633974483;


"""
    )
    return jac_code


def create_ls_with_workspace(file_path: str):
    """Create JacLangServer and workspace for a given file path, return (uri, ls)."""
    from jaclang.langserve.engine import JacLangServer

    ls = JacLangServer()
    uri = from_fs_path(file_path)
    ls.lsp._workspace = Workspace(os.path.dirname(file_path), ls)
    return uri, ls
