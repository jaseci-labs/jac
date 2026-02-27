"""Test fixture for JSX fragments and spread props functionality."""

cl def FragmentTest() {
    # Test that fragments work
    return <>
        <h1>
            {"Fragment Title"}
        </h1>
        <p>
            {"Fragment content"}
        </p>
    </>;
}

cl def SpreadPropsTest() {
    # Test spread props
    unwrapped = {"id": "my-div", "class": "container", "data-role": "main"};

    return <div
        {...unwrapped}
    >
        <span>
            {"Spread props work!"}
        </span>
    </div>;
}

cl def MixedTest() {
    # Test mixing spread props with regular props
    baseStyle = {"id": "base-id", "color": "blue"};

    return <>
        <div
            {...baseStyle}
            class="override"
        >
            {"Mixed test"}
        </div>
        <div class="normal">
            {"No spread"}
        </div>
    </>;
}

cl def NestedFragments() {
    return <div class="wrapper">
        <>
            <h2>
                {"Nested Fragment 1"}
            </h2>
        </>
        <>
            <p>
                {"Nested Fragment 2"}
            </p>
        </>
    </div>;
}

cl def app() {
    return <div>
        <FragmentTest />
        <SpreadPropsTest />
        <MixedTest />
        <NestedFragments />
    </div>;
}
