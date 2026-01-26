cl import from '@mui/material/Button' { default as Button }
cl import from '@mui/material/Card' { default as Card }
cl import from '@mui/material/CardContent' { default as CardContent }
cl import from '@mui/material/CardActions' { default as CardActions }
cl import from '@mui/material/Typography' { default as Typography }
cl import from '@mui/material/IconButton' { default as IconButton }
cl import from '@mui/material/Box' { default as Box }
cl import from '@mui/material/Divider' { default as Divider }
cl import from '@mui/icons-material/Add' { default as AddIcon }
cl import from '@mui/icons-material/Remove' { default as RemoveIcon }
cl import from '@mui/icons-material/Refresh' { default as RefreshIcon }

cl {
    def:pub app -> any {
        has count: int = 0;

        can with count entry {
            console.log("Count changed: ", count);
        }

        handleIncrement = lambda e: any  -> None { count = count + 1;};

        handleDecrement = lambda e: any  -> None { count = count - 1;};

        handleReset = lambda e: any  -> None { count = 0;};

        return
            <Box
                sx={{
                    "display": "flex",
                    "justifyContent": "center",
                    "alignItems": "center",
                    "minHeight": "100vh",
                    "backgroundColor": "#f5f5f5"
                }}
            >
                <Card sx={{"minWidth": 400, "boxShadow": 3}}>
                    <CardContent>
                        <Typography
                            variant="h4"
                            component="div"
                            gutterBottom
                            sx={{"textAlign": "center", "color": "primary.main"}}
                        >
                            Counter Application
                        </Typography>
                        <Divider sx={{"my": 2}} />
                        <Box
                            sx={{
                                "display": "flex",
                                "flexDirection": "column",
                                "alignItems": "center",
                                "py": 3
                            }}
                        >
                            <Typography
                                variant="h6"
                                color="text.secondary"
                                gutterBottom
                            >
                                Current Count
                            </Typography>
                            <Typography
                                variant="h1"
                                component="div"
                                sx={{
                                    "fontWeight": "bold",
                                    "color": "success.main"
                                    if count > 0
                                    else "error.main" if count < 0 else "text.primary"
                                }}
                            >
                                {count}
                            </Typography>
                        </Box>
                    </CardContent>
                    <Divider />
                    <CardActions
                        sx={{
                            "display": "flex",
                            "justifyContent": "space-around",
                            "p": 2
                        }}
                    >
                        <IconButton
                            color="error"
                            size="large"
                            onClick={handleDecrement}
                            sx={{"border": "2px solid", "borderColor": "error.main"}}
                        >
                            <RemoveIcon />
                        </IconButton>
                        <IconButton
                            color="primary"
                            size="large"
                            onClick={handleReset}
                            sx={{"border": "2px solid", "borderColor": "primary.main"}}
                        >
                            <RefreshIcon />
                        </IconButton>
                        <IconButton
                            color="success"
                            size="large"
                            onClick={handleIncrement}
                            sx={{"border": "2px solid", "borderColor": "success.main"}}
                        >
                            <AddIcon />
                        </IconButton>
                    </CardActions>
                    <Box sx={{"px": 3, "pb": 2}}>
                        <Typography
                            variant="caption"
                            color="text.secondary"
                            sx={{"display": "block", "textAlign": "center"}}
                        >
                            Click the buttons to increment, decrement, or reset the counter
                        </Typography>
                    </Box>
                </Card>
            </Box>;
    }
}
