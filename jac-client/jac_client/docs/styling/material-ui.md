# Material-UI

Comprehensive React component library with Material Design for Jac applications.

## Overview

Material-UI (MUI) provides pre-built, accessible React components following Material Design principles. This approach is perfect for:

- Rapid application development
- Consistent Material Design
- Accessible components out of the box
- Enterprise applications

## Example

See the complete working example: [`examples/css-styling/material-ui/`](../../examples/css-styling/material-ui/)

## Quick Start

### 1. Install Material-UI

Add to `package.json`:

```json
{
  "dependencies": {
    "@mui/material": "^5.15.0",
    "@mui/icons-material": "^5.15.0"
  }
}
```

### 2. Import Components

In your Jac file:

```jac
# Pages
cl import from react { useEffect }
cl import from "@mui/material/Button" { default as Button }

# Note: useState is auto-injected when using `has` variables
cl import from "@mui/material/Card" { default as Card }
cl import from "@mui/material/CardContent" { default as CardContent }
cl import from "@mui/material/Box" { default as Box }
cl import from "@mui/icons-material/Add" { default as AddIcon }
cl import from "@mui/icons-material/Remove" { default as RemoveIcon }

cl {
    def app() -> JsxElement {
        return <Box sx={{"display": "flex", "justifyContent": "center"}}>
            <Card>
                <CardContent>
                    <Button variant="contained" onClick={handleIncrement}>
                        <AddIcon />
                    </Button>
                </CardContent>
            </Card>
        </Box>;
    }
}
```

## Key Features

### Theming

Material-UI comes with a built-in theme system:

```javascript
import { ThemeProvider, createTheme } from '@mui/material/styles';

const theme = createTheme({
    palette: {
        primary: {
            main: '#1976d2',
        },
        secondary: {
            main: '#dc004e',
        },
    },
    typography: {
        fontFamily: 'Roboto, Arial, sans-serif',
    },
    spacing: 8, // 8px base unit
});

// Wrap your app
<ThemeProvider theme={theme}>
    <App />
</ThemeProvider>
```

### sx Prop

Use the `sx` prop for styling:

```jac
<Box sx={{
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    minHeight: "100vh",
    backgroundColor: "background.default"
}}>
    <Card sx={{
        maxWidth: 400,
        padding: 2
    }}>
        Content
    </Card>
</Box>
```

### Component Variants

Use built-in variants:

```jac
<Button variant="contained" color="primary">Contained</Button>
<Button variant="outlined" color="secondary">Outlined</Button>
<Button variant="text">Text</Button>
```

## Common Components

### Layout Components

```jac
# Box - Container component
<Box sx={{"display": "flex", "gap": 2}}>
    <Box>Item 1</Box>
    <Box>Item 2</Box>
</Box>

# Grid - Responsive grid system
cl import from "@mui/material/Grid" { default as Grid }
<Grid container spacing={2}>
    <Grid item xs={12} md={6}>Column 1</Grid>
    <Grid item xs={12} md={6}>Column 2</Grid>
</Grid>

# Stack - Flexbox container
cl import from "@mui/material/Stack" { default as Stack }
<Stack direction="row" spacing={2}>
    <Button>Button 1</Button>
    <Button>Button 2</Button>
</Stack>
```

### Input Components

```jac
# TextField
cl import from "@mui/material/TextField" { default as TextField }
<TextField label="Name" variant="outlined" />

# Button
<Button variant="contained" color="primary" onClick={handleClick}>
    Click Me
</Button>

# Select
cl import from "@mui/material/Select" { default as Select }
cl import from "@mui/material/MenuItem" { default as MenuItem }
<Select value={value} onChange={handleChange}>
    <MenuItem value="option1">Option 1</MenuItem>
    <MenuItem value="option2">Option 2</MenuItem>
</Select>
```

### Feedback Components

```jac
# Card
<Card>
    <CardContent>
        <Typography variant="h5">Card Title</Typography>
        <Typography variant="body2">Card content</Typography>
    </CardContent>
</Card>

# Dialog
cl import from "@mui/material/Dialog" { default as Dialog }
cl import from "@mui/material/DialogTitle" { default as DialogTitle }
<Dialog open={open} onClose={handleClose}>
    <DialogTitle>Dialog Title</DialogTitle>
</Dialog>

# Snackbar
cl import from "@mui/material/Snackbar" { default as Snackbar }
cl import from "@mui/material/Alert" { default as Alert }
<Snackbar open={open} autoHideDuration={6000}>
    <Alert severity="success">Success message!</Alert>
</Snackbar>
```

## Best Practices

### 1. Use sx Prop

For component-specific styling:

```jac
<Box sx={{
    display: "flex",
    justifyContent: "center",
    padding: 2,
    backgroundColor: "primary.main"
}}>
```

### 2. Leverage Variants

Use built-in variants when possible:

```jac
<Button variant="contained" color="primary">Primary</Button>
<Typography variant="h1">Heading</Typography>
```

### 3. Theme Customization

Customize theme for brand colors:

```javascript
const theme = createTheme({
    palette: {
        primary: {
            main: '#your-brand-color',
        },
    },
});
```

### 4. Accessibility

MUI components are accessible by default:

```jac
<Button aria-label="Add item">
    <AddIcon />
</Button>
```

### 5. Icons

Use @mui/icons-material for consistent icons:

```jac
cl import from "@mui/icons-material/Add" { default as AddIcon }
cl import from "@mui/icons-material/Delete" { default as DeleteIcon }
cl import from "@mui/icons-material/Edit" { default as EditIcon }
```

## Advantages

- **Pre-built, accessible components**
- **Consistent Material Design**
- **Comprehensive component library**
- **Built-in theming system**
- **TypeScript support**
- **Active community** and documentation
- **Production-ready** components

## Limitations

- **Larger bundle size**
- **Material Design aesthetic** (may not fit all brands)
- **Learning curve** for component API
- **Less flexibility** than custom CSS
- **Requires JavaScript** for styling

## When to Use

Choose Material-UI when:

- You want pre-built components
- You need accessible components
- You prefer Material Design
- You're building enterprise applications
- You want to focus on functionality over styling
- You need comprehensive component library

## Import Syntax

MUI components are imported from their specific packages:

```jac
# Material components
cl import from "@mui/material/Button" { default as Button }
cl import from "@mui/material/Card" { default as Card }

# Icons
cl import from "@mui/icons-material/Add" { default as AddIcon }
cl import from "@mui/icons-material/Delete" { default as DeleteIcon }

# Multiple imports
cl import from "@mui/material" {
    Button,
    Card,
    CardContent,
    Box
}
```

## Theming Example

```javascript
// theme.js
import { createTheme } from '@mui/material/styles';

export const theme = createTheme({
    palette: {
        mode: 'light',
        primary: {
            main: '#1976d2',
        },
        secondary: {
            main: '#dc004e',
        },
    },
    typography: {
        fontFamily: 'Roboto, Arial, sans-serif',
        h1: {
            fontSize: '2.5rem',
        },
    },
    spacing: 8,
});
```

## Next Steps

- Explore [Material-UI Documentation](https://mui.com/)
- Check out Chakra UI for alternative component library (coming soon)
- Learn about Ant Design for enterprise components (coming soon)
- See [Styled Components](./styled-components.md) for CSS-in-JS approach

## Resources

- [Material-UI Documentation](https://mui.com/)
- [Material-UI Components](https://mui.com/material-ui/getting-started/)
- [Material Design Guidelines](https://m3.material.io/)
