# When to Mock

Mock at **system boundaries** only:

- External services (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```
Easy to mock:
  processPayment(order, paymentGateway):
    return paymentGateway.charge(order.total)

Hard to mock:
  processPayment(order):
    gateway = createProductionPaymentGateway()
    return gateway.charge(order.total)
```

**2. Prefer operation-specific interfaces over generic transport wrappers**

Create explicit operations for each external action instead of one generic request function with branching logic.

```
GOOD, explicit operations:
  userService.getUser(id)
  userService.getOrders(userId)
  orderService.createOrder(data)

BAD, one generic transport:
  api.request(method, path, payload)
```

The explicit operation approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which operations a test exercises
