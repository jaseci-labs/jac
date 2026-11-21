import from "solid-js/web" { render }

with entry {
    render(lambda -> any { return <Playground lib="Solid" />; }, document.getElementById("root"));
}
