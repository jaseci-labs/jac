"""Fixture to test string literal imports for hyphenated package names.

This fixture tests the ability to import from npm packages with hyphens
in their names using string literals, which is necessary since hyphens
cannot be used in unquoted identifiers.
"""

cl {
    # Test 1: react-dom - named imports
    import from "react-dom" { render, hydrate }

    # Test 2: react-dom - named import with alias
    import from "react-dom" { render as renderDOM }

    # Test 3: react-dom - namespace import
    import from "react-dom" { * as ReactDOM }

    # Test 4: react-dom - default import
    import from "react-dom" { default as ReactDOMDefault }

    # Test 5: react-dom - mixed default and named
    import from "react-dom" { default as RD, createPortal }

    # Test 6: styled-components - default import
    import from "styled-components" { default as styled }

    # Test 7: date-fns - multiple named imports
    import from "date-fns" { format, parse, addDays }

    # Test 8: react-router-dom - multiple named imports
    import from "react-router-dom" { BrowserRouter, Route, Link }

    # Test 9: Can still use regular (non-string) imports for non-hyphenated packages
    import from react { useState, useEffect }
    import from lodash { map, filter }

    def TestComponent() {
        # Use some of the imports to ensure they're valid
        ReactDOM.render();
        styled.div();
        return "test";
    }
}
