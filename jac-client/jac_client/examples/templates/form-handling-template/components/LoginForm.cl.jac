
# React Hook Form + Zod + Zustand Example
import from react { useState }
import from "react-hook-form" { useForm }
import from "@hookform/resolvers/zod" { zodResolver }
import from ..schema.loginSchema {
    loginSchema
}
import from ..store.useFormStore { useFormStore }

  

# Login Form Component
def:pub LoginForm() -> any {
    loginUser = useFormStore(lambda state: any -> any { return state.loginUser; });
    isLoggedIn = useFormStore(lambda state: any -> any { return state.isLoggedIn; });
    currentUser = useFormStore(lambda state: any -> any { return state.currentUser; });
    logoutUser = useFormStore(lambda state: any -> any { return state.logoutUser; });

    form = useForm({
        "resolver": zodResolver(loginSchema()),
        "defaultValues": {
            "username": "",
            "password": "",
            
        }
    });

    register = form.register;
    usernameField = register("username");
    passwordField = register("password");
    handleSubmit = form.handleSubmit;
    errors = form.formState.errors;

    onSubmit = lambda data: any -> None {
        console.log("Login Data:", data);
        loginUser(data);
    };


    if isLoggedIn {
        return <div style={{border: "2px solid #10b981", borderRadius: "12px", padding: "24px", backgroundColor: "#d1fae5"}}>
            <h2 style={{margin: "0 0 20px", color: "#065f46"}}> Logged In</h2>
            <p style={{margin: "0 0 16px", color: "#065f46"}}>
                Welcome, {currentUser.username}!
            </p>
            <button
                onClick={lambda e: any -> None { logoutUser(); }}
                style={{padding: "10px 20px", backgroundColor: "#dc2626", color: "white", border: "none", borderRadius: "6px", cursor: "pointer"}}
            >
                Logout
            </button>
        </div>;
    }

    return <div style={{border: "2px solid #8b5cf6", borderRadius: "12px", padding: "24px", backgroundColor: "white"}}>
        <h2 style={{margin: "0 0 20px", color: "#6d28d9"}}>Login Form</h2>

        <form onSubmit={handleSubmit(onSubmit)}>
            # Email
            <div style={{marginBottom: "16px"}}>
                <label style={{display: "block", marginBottom: "6px", fontWeight: "600", color: "#374151"}}>
                    Email *
                </label>
                <input
                    name={usernameField.name}
                    onChange={usernameField.onChange}
                    onBlur={usernameField.onBlur}
                    ref={usernameField.ref}
                    type="text"
                    placeholder="yourusername"
                    style={{width: "100%", padding: "10px", border: "1px solid #d1d5db", borderRadius: "6px", fontSize: "14px"}}
                />
                {errors.username && (
                    <p style={{margin: "4px 0 0", color: "#dc2626", fontSize: "12px"}}>
                        {errors.username.message}
                    </p>
                )}
            </div>

            # Password
            <div style={{marginBottom: "16px"}}>
                <label style={{display: "block", marginBottom: "6px", fontWeight: "600", color: "#374151"}}>
                    Password *
                </label>
                <input
                    name={passwordField.name}
                    onChange={passwordField.onChange}
                    onBlur={passwordField.onBlur}
                    ref={passwordField.ref}
                    type="password"
                    placeholder="Enter your password"
                    style={{width: "100%", padding: "10px", border: "1px solid #d1d5db", borderRadius: "6px", fontSize: "14px"}}
                />
                {errors.password && (
                    <p style={{margin: "4px 0 0", color: "#dc2626", fontSize: "12px"}}>
                        {errors.password.message}
                    </p>
                )}
            </div>

            

            <button
                type="submit"
                style={{width: "100%", padding: "12px", backgroundColor: "#8b5cf6", color: "white", border: "none", borderRadius: "6px", fontSize: "16px", fontWeight: "600", cursor: "pointer"}}
            >
                Login
            </button>
        </form>

        
    </div>;
}
