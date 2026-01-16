"""Main entry point for the Jac client application."""

# Client-side imports (useState is auto-injected when using `has` variables)
cl import from react { useEffect }
cl import from .components.Button { Button }
cl import from "motion/react" { motion }
cl import from .components.scroll { ScrollTriggered }

# Client-side component
cl {
    def:pub app() -> any {


        return <div style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}>

            <motion.div
            style={{width: 100, height: 100, backgroundColor: "#3498db", borderRadius: 10}}
            animate={{ rotate: 360 }}
            transition={{ duration: 1 }}
            />
            <motion.div
                whileHover={{ scale: 1.2 }}
                whileTap={{ scale: 0.8 }}
                style={{width: 100, height: 100, backgroundColor: "#e74c3c", borderRadius: 10}}
            />
            <ScrollTriggered />

            </div>;

    }
}
