
"""Main entry point for the Jac client application."""

cl import  from .components.LoginForm { LoginForm }


# Client-side component
cl {
    def:pub app() -> any {


        return <div style={{fontFamily: "Arial, sans-serif", backgroundColor: "#f3f4f6", minHeight: "100vh", display: "flex", justifyContent: "center", alignItems: "center", padding: "20px"}}>
            <div style={{maxWidth: "400px", width : "100%"}}>
                <LoginForm />
            </div>
        </div>;
    }
}
