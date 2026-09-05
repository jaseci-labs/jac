impl Navbar.toggle_theme(_e: MouseEvent) {
    if dark {
        document.documentElement.classList.remove("dark");
        localStorage.setItem("jac-theme", "light");
        dark = False;
    } else {
        document.documentElement.classList.add("dark");
        localStorage.setItem("jac-theme", "dark");
        dark = True;
    }
}
