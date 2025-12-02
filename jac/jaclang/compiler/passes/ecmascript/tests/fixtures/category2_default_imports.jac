"""Category 2: Default Imports - Test fixture for default import pattern validation.

This fixture tests the following pattern from the proposal:
- Default import: import from module { default as Name }

Based on the table in jac_import_patterns_proposal.md:
| JavaScript Pattern            | Jac Pattern                           |
|-------------------------------|---------------------------------------|
| import React from 'react'     | cl import from react { default as React } |
| import axios from 'axios'     | cl import from axios { default as axios } |
| import Vue from 'vue'         | cl import from vue { default as Vue }     |
"""

cl {
    # Default import examples
    import from react { default as React }
    import from axios { default as axios }
    import from vue { default as Vue }

    # Default import with relative paths
    import from .components.Button { default as Button }
    import from ..lib.utils { default as utils }

    # Using imported defaults
    def example_usage() {
        let app = Vue.createApp({});
        axios.get("/api/data");
        let element = React.createElement("div", {}, "Hello");

        return element;
    }
}
