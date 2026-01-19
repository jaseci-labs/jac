"""Main entry point for i18n-template."""


cl import from .pages.home { Home }



# Client-side component
cl {
    def:pub app() -> any {
      

        return <div style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}>
        <Home />
        </div>;
    }
}
