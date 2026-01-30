import from react { useContext }
import from '..lib.auth' { AuthContext }

def:pub Dashboard() -> any {
    ctx = useContext(AuthContext);
    console.log("DASHBOARD CTX:", ctx);

    return <div>
        <h1>Dashboard</h1>
        <p>Hello {ctx.user.name}</p>
    </div>;
}
