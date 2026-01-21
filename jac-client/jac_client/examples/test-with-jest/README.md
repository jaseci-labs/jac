
# Jac Component Testing Example

This project demonstrates how to structure and test UI components in a
Jac Client application.

## Key Principles

- Jac tests focus on **logic**, not rendering
- JSX output is not unit-tested
- All testable behavior is extracted into pure helper functions
- Components remain thin and declarative

## Folder Structure

```

components/
Button.jac        # UI component
Badge.jac         # UI component
logic.jac         # Shared testable logic
components.test.jac # Unit tests
main.jac            # App entry point

```

## What Is Tested

✅ Variant normalization  
✅ Disabled / interactive logic  
✅ Style computation  
✅ Guard conditions  

## What Is NOT Tested

❌ JSX structure  
❌ DOM behavior  
❌ Click events  
❌ Hooks / `has` state  

This is intentional and aligns with Jac’s deterministic testing model.

## Running Tests

```bash
jac test
```

## Why This Pattern Works

* Tests are fast and deterministic
* UI remains flexible
* Refactoring JSX does not break tests
* Logic bugs are caught early

## Recommendation

For every component:

1. Extract logic into pure functions
2. Export helpers with `def:pub`
3. Test helpers, not JSX
4. Keep components thin

This scales cleanly for large Jac applications.


---

# Final takeaway (important)

You now have:
- ✅ **Real components**
- ✅ **Real tests**
- ✅ **Correct Jac testing model**
- ✅ **Scalable architecture**

If you want next, we can:
- Add **Todo app logic tests**
- Test **filtering / sorting logic**
- Apply this pattern to **walkers**
- Design a **component library structure**

Say the word.

