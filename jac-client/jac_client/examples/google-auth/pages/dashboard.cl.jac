import from react { useContext }
import from '..lib.auth' { AuthContext }

def:pub Dashboard -> JsxElement {
    ctx = useContext(AuthContext);
    console.log("DASHBOARD CTX:", ctx);

    return
        <div style={{padding: '2rem', maxWidth: '800px', margin: '0 auto'}}>
            <h1>
                Dashboard
            </h1>
            <p>
                Hello,{ctx.user.name}!
            </p>
            <p>
                Email:{ctx.user.email}
            </p>
            <button
                onClick={ctx.handleLogout}
                style={{
                    marginTop: '1rem',
                    padding: '0.5rem 1rem',
                    cursor: 'pointer',
                    backgroundColor: '#dc3545',
                    color: 'white',
                    border: 'none',
                    borderRadius: '4px'
                }}
            >
                Logout
            </button>
        </div>;
}
