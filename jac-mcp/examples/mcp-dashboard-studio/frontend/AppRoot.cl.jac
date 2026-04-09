"""Root component — routes between HomePage and DashboardPage."""
import from ".Dashboard" { DashboardPage }
import from ".HomePage" { HomePage }

def:pub AppRoot -> JsxElement {
    has page: str = "home";

    if page == "dashboard" {
        return
            <DashboardPage onBack={lambda { page = "home";}}/>;
    }
    return
        <HomePage onEnter={lambda { page = "dashboard";}}/>;
}
