# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```
Test "user can checkout with valid cart":
  cart = newCart()
  cart.add(product)
  result = checkout(cart, paymentMethod)
  assert result.status == "confirmed"
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```
Test "checkout calls payment processor":
  spy on paymentProcessor.charge
  checkout(cart, paymentMethod)
  assert paymentProcessor.charge called with cart.total
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```
BAD, bypasses interface:
  createUser(name = "Alice")
  row = queryUsersStoreByName("Alice")
  assert row exists

GOOD, verifies through interface:
  user = createUser(name = "Alice")
  retrieved = getUser(user.id)
  assert retrieved.name == "Alice"
```
