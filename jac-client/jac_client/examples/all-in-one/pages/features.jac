cl {
    import from .features_test_ui { FeaturesTest as FeaturesTestUI }

    def:pub page -> JsxElement {
        return
            <FeaturesTestUI />;
    }
}
