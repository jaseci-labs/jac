# Counter app styled with Material UI components.
cl import from '@mui/material/Button' { default as Button }
cl import from '@mui/material/Typography' { default as Typography }
cl import from '@mui/material/Box' { default as Box }

cl {
    def:pub app -> JsxElement {
        has count: int = 0;

        handleIncrement = lambda e: any { count = count + 1; };

        return
            <Box
                sx={{
                    "display": "flex",
                    "flexDirection": "column",
                    "alignItems": "center",
                    "minHeight": "100vh"
                }}
            >
                <Typography variant="h1" sx={{"fontWeight": "bold"}}>
                    {count}
                </Typography>
                <Button variant="contained" onClick={handleIncrement}>+</Button>
            </Box>;
    }
}
