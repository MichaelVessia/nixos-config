# Interface Design for Testability

Good interfaces make testing natural:

1. **Accept dependencies, don't create them**

   ```
   Testable:
     processOrder(order, paymentGateway)

   Hard to test:
     processOrder(order):
       gateway = createProductionGateway()
   ```

2. **Return results, don't produce side effects**

   ```
   Testable:
     discount = calculateDiscount(cart)

   Hard to test:
     applyDiscount(cart):
       cart.total = cart.total - discount
   ```

3. **Small surface area**
   - Fewer methods = fewer tests needed
   - Fewer params = simpler test setup

For TypeScript-specific examples and tooling, see [typescript.md](./typescript.md).
For Rust-specific tips, see [rust.md](./rust.md).
For Go-specific tips, see [golang.md](./golang.md).
