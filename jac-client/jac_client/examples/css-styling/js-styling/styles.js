// Style objects for the counter app
const countDisplay = {
    fontSize: "3.75rem",
    fontWeight: "bold",
    transition: "color 0.3s ease"
};

const button = {
    color: "#ffffff",
    fontWeight: "bold",
    padding: "0.75rem 1.5rem",
    borderRadius: "0.5rem",
    boxShadow: "0 10px 15px -3px rgba(0, 0, 0, 0.1)",
    transition: "all 0.2s ease",
    fontSize: "1.25rem",
    border: "none",
    cursor: "pointer"
};

export default {
    container: {
        minHeight: "100vh",
        background: "linear-gradient(to bottom right, #dbeafe, #e0e7ff)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "1rem"
    },
    card: {
        backgroundColor: "#ffffff",
        borderRadius: "1rem",
        boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.25)",
        padding: "2rem",
        maxWidth: "28rem",
        width: "100%"
    },
    title: {
        fontSize: "1.875rem",
        fontWeight: "bold",
        color: "#1f2937",
        textAlign: "center",
        marginBottom: "1.5rem"
    },
    divider: {
        height: "1px",
        background: "linear-gradient(to right, transparent, #d1d5db, transparent)",
        marginBottom: "1.5rem"
    },
    counterSection: {
        textAlign: "center",
        marginBottom: "2rem"
    },
    label: {
        fontSize: "0.875rem",
        fontWeight: "600",
        color: "#4b5563",
        marginBottom: "0.5rem",
        textTransform: "uppercase",
        letterSpacing: "0.05em"
    },
    countDisplay: countDisplay,
    countDisplayZero: {
        ...countDisplay,
        color: "#1f2937"
    },
    countDisplayPositive: {
        ...countDisplay,
        color: "#16a34a"
    },
    countDisplayNegative: {
        ...countDisplay,
        color: "#dc2626"
    },
    buttonGroup: {
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        gap: "1rem",
        marginBottom: "1.5rem"
    },
    button: button,
    buttonDecrement: {
        ...button,
        backgroundColor: "#ef4444"
    },
    buttonReset: {
        ...button,
        backgroundColor: "#6b7280"
    },
    buttonIncrement: {
        ...button,
        backgroundColor: "#22c55e"
    },
    hint: {
        textAlign: "center",
        fontSize: "0.875rem",
        color: "#6b7280",
        fontStyle: "italic"
    }
};
