cl {
    import from .FieldExamples { FieldExamples }
    import from "@jac/runtime" { Router, Routes, Route }

    def:pub app -> JsxElement {
        return
            <Router>
                <Routes>
                    <Route path="/" element={<FieldExamples/>}/>
                </Routes>
            </Router>;
    }
}
