"""Category 4: Namespace Imports - Test fixture for namespace import pattern validation.

This fixture tests the following pattern from the proposal:
- Namespace import: import from module { * as Name }

Based on the table in jac_import_patterns_proposal.md:
| JavaScript Pattern                 | Jac Pattern                           |
|------------------------------------|---------------------------------------|
| import * as React from 'react'     | cl import from react { * as React }   |
| import * as _ from 'lodash'        | cl import from lodash { * as _ }      |
| import * as utils from './utils'   | cl import from .utils { * as utils }  |
"""

cl {
    # Namespace import examples
    import from react { * as React }
    import from lodash { * as _ }
    import from dateutils { * as DateUtils }

    # Namespace import with relative paths
    import from .utils { * as utils }
    import from ..lib.helpers { * as helpers }

    # Using imported namespaces
    def example_usage() {
        component = React.createElement("div", {}, "Hello");
        numbers = [1, 2, 3];
        now = DateUtils.formatDate();

        result = utils.processData({});
        helpers.logMessage("Processing complete");

        return component;
    }
}
