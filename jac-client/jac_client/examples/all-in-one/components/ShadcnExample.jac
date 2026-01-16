"""Example component demonstrating shadcn UI usage."""

# Import shadcn UI components
cl import from "@components/ui/button" { Button }
cl import from "@components/ui/card" {
    Card,
    CardHeader,
    CardTitle,
    CardDescription,
    CardContent,
    CardFooter
}

cl {
    def ShadcnExample() -> any {
        has count: int = 0;
        
        def handleIncrement() {
            count = count + 1;
        }
        
        def handleDecrement() {
            count = count - 1;
        }
        
        return <div style={{"padding": "2rem", "maxWidth": "600px", "margin": "0 auto"}}>
            <Card>
                <CardHeader>
                    <CardTitle>shadcn UI Example</CardTitle>
                    <CardDescription>
                        This component demonstrates how to use shadcn UI components in Jac.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <div style={{"display": "flex", "flexDirection": "column", "gap": "1rem"}}>
                        <p style={{"fontSize": "1.5rem", "textAlign": "center"}}>
                            Count: {count}
                        </p>
                        <div style={{"display": "flex", "gap": "1rem", "justifyContent": "center"}}>
                            <Button variant="default" onClick={handleIncrement}>
                                Increment
                            </Button>
                            <Button variant="secondary" onClick={handleDecrement}>
                                Decrement
                            </Button>
                            <Button variant="outline" onClick={lambda -> None { count = 0; }}>
                                Reset
                            </Button>
                        </div>
                    </div>
                </CardContent>
                <CardFooter>
                    <p style={{"fontSize": "0.875rem", "color": "#6b7280"}}>
                        Built with shadcn UI components
                    </p>
                </CardFooter>
            </Card>
        </div>;
    }
}

