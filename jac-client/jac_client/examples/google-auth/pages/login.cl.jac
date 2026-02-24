import from react { useContext }
import from "@jac/runtime" { Navigate, useNavigate }
import from '..lib.auth' { AuthContext }
import from '..components.Button' { Button }

cl def:pub Login -> JsxElement {
    auth = useContext(AuthContext);
    navigate = useNavigate();

    # If already logged in, redirect to dashboard
    if auth.user {
        return
            <Navigate to="/dashboard" replace/>;
    }

    # Handle Google login - redirects to backend
    def handleGoogleLogin -> None {
        auth.handleLogin('google');
    }
    ;

    return (
        <div
            style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                minHeight: '100vh',
                gap: '2rem'
            }}
        >
            <h1>
                Login to Your Account
            </h1>
            <div
                style={{
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '1rem',
                    padding: '2rem',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    minWidth: '300px',
                    color: '#333',
                    backgroundColor: '#f9f9f9'
                }}
            >
                <Button onClick={handleGoogleLogin} label="Sign in with Google"/>
                <div style={{textAlign: 'center', marginTop: '1rem'}}>
                    <p>
                        Don't have an account?
                    </p>
                    <button
                        onClick={lambda() -> None { auth.handleRegister('google');}}
                        style={{
                            background: 'none',
                            border: 'none',
                            color: '#007bff',
                            cursor: 'pointer',
                            textDecoration: 'underline'
                        }}
                    >
                        Register with Google
                    </button>
                </div>
            </div>
        </div>
    );
}
