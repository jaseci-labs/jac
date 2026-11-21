"""Dual-platform fixture: shared main.jac with web/native header variants.

The web build picks ``src/header.jac`` (className + CSS); the native
build picks ``src/header.native.jac`` (inline styles only).
"""
walker:pub get_greeting {
    can greet with Root entry {
        report "hello from backend";
    }
}


import from '@jac/runtime' { Router, Routes, Route }
import from .src.header { PlatformHeader }

import "./src/styles.css";

def:pub HomePage -> JsxElement {
    has greeting: str = "";

    async can with entry {
        result = root spawn get_greeting();
        if result.reports and len(result.reports) > 0 {
            greeting = str(result.reports[0]);
        }
    }

    <div>
        <PlatformHeader title="Home"/>
        <p data-testid="greeting">{greeting}</p>
    </div>
}

def:pub app -> JsxElement {
    <Router>
        <Routes>
            <Route path="/" element={<HomePage/>}/>
        </Routes>
    </Router>
}
