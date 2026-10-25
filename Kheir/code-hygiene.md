# Best Code Hygiene Practices

Good code hygiene makes software easier to understand, test, debug, maintain, and safely change. The goal isn't to make code look perfect—it is to reduce unnecessary complexity and make future work predictable.

## 1. Keep Code Simple

Prefer straightforward solutions over clever ones.

- Use clear control flow.
- Avoid unnecessary abstractions.
- Don't optimize code before you know optimization is needed.
- Keep functions focused on one responsibility.
- Delete code that no longer serves a purpose.

A useful rule: if a reasonable developer can't understand a function quickly, consider simplifying it.

## 2. Use Meaningful Names

Names should communicate intent.

Prefer:

```python
calculateMonthlyRevenue()
userAccount
expirationDate
```

over:

```python
calc()
data
x
tmp
```

Avoid abbreviations unless they are universally understood within the project.

Boolean variables should generally read naturally:

```python
isAuthenticated
hasPermission
shouldRetry
```

## 3. Keep Functions Small and Focused

A function should ideally do one logical thing.

Instead of `processOrder()` doing validation, payment processing, database updates, email notifications, and analytics, separate those responsibilities:

```python
validateOrder()
chargePayment()
saveOrder()
sendConfirmation()
recordAnalytics()
```

Small functions are easier to test and reuse.

## 4. Don't Duplicate Logic

If the same business logic appears in multiple places, consider extracting it into a shared function or module.

Bad:

```python
if user.age >= 18:
    ...
```

repeated throughout the application.

Better:

```python
if isAdult(user):
    ...
```

However, don't create abstractions merely because two pieces of code happen to look similar. Duplicate simple code can be better than an overly complicated abstraction.

## 5. Handle Errors Explicitly

Don't silently ignore errors.

Bad:

```python
try:
    saveUser()
except:
    pass
```

Better:

```python
try:
    saveUser()
except DatabaseError as error:
    logError(error)
    return failure
```

Errors should either be:

- Handled appropriately,
- Returned to the caller, or
- Propagated with enough context to diagnose the problem.

Avoid catching overly broad exceptions unless there is a specific reason.

## 6. Validate Inputs at Boundaries

Treat external input as untrusted.

Validate data coming from:

- Users
- APIs
- Databases
- Files
- Environment variables
- Command-line arguments
- Third-party services

For example: `request → validate → application logic → database`

Don't assume that data is valid simply because your own code normally produces it.

## 7. Keep Configuration Out of Source Code

Never hard-code secrets such as:

```python
API_KEY = "..."
DATABASE_PASSWORD = "..."
```

Use environment variables or an appropriate secrets manager:

```python
API_KEY = environment.get("API_KEY")
```

Also make sure secrets aren't accidentally committed to Git.

Useful protections include:

- `.gitignore`
- Secret scanning
- Pre-commit hooks
- CI/CD secret detection

If a secret is accidentally committed, rotate it rather than simply deleting it from the latest commit.

## 8. Use Version Control Properly

Make commits small and meaningful.

Good:

```
Add authentication middleware
Fix expired-session handling
Add tests for payment failures
```

Less useful:

```
stuff
changes
fixed things
updates
```

A commit should ideally represent one logical change.

Before committing:

```bash
git status
git diff
git diff --cached
```

Review what you're actually committing.

## 9. Never Commit Generated or Local Files Unless Necessary

Keep temporary and machine-specific files out of the repository.

Common examples:

```
node_modules/
.env
.DS_Store
*.log
dist/
build/
.cache/
```

The exact `.gitignore` depends on your language and framework.

## 10. Format Automatically

Use automated formatters rather than manually arguing about formatting.

Examples include:

- Prettier
- Black
- Ruff
- gofmt
- rustfmt
- clang-format

Ideally, formatting runs automatically through your editor or pre-commit workflow.

This keeps code reviews focused on behavior rather than whitespace.

## 11. Lint Early

Linters catch many problems before they become bugs.

Examples:

- unused variables
- unreachable code
- incorrect imports
- dangerous patterns
- inconsistent style
- potential bugs

Run linting locally and in CI.

Don't blindly disable lint rules. If a rule is inappropriate for your project, configure it deliberately.

## 12. Write Tests Around Behavior

Tests should verify what the software is supposed to do.

Prioritize:

- Critical business logic
- Authentication and authorization
- Payments
- Data transformations
- Important edge cases
- Bug fixes

A useful pattern is Arrange, Act, Assert.

Example:

```
Arrange:
    create an expired session

Act:
    request a protected resource

Assert:
    request is rejected
```

When fixing a bug, consider adding a regression test so the bug doesn't return.

## 13. Test Edge Cases

Don't test only the happy path.

Consider:

- empty input
- null/missing values
- very large values
- invalid formats
- duplicate requests
- expired credentials
- network failures
- timeouts
- permission failures
- concurrent operations

The most valuable tests often live around boundaries and failure conditions.

## 14. Keep Dependencies Under Control

Before adding a package, ask:

- Do we actually need it?
- Is the project maintained?
- Is the dependency trustworthy?
- Does it introduce unnecessary complexity?
- Could this functionality reasonably be implemented ourselves?

Keep dependencies updated, but don't blindly update everything in production without testing.

Remove dependencies that are no longer needed.

## 15. Keep Modules Focused

A module should have a coherent purpose.

Avoid giant files such as:

```
utils.js
helpers.py
common.ts
misc.go
```

containing hundreds of unrelated functions.

Prefer modules organized around meaningful responsibilities.

## 16. Comment the "Why," Not the "What"

Bad:

```python
# Increment counter by one
counter += 1
```

The code already explains that.

Better:

```python
# Retry once because the upstream service occasionally returns
# a transient 503 immediately after deployment.
retryCount += 1
```

Comments are most valuable when they explain:

- Business rules
- Non-obvious decisions
- Workarounds
- Constraints
- Performance considerations
- External system behavior

Delete comments that become inaccurate.

## 17. Avoid Magic Numbers and Strings

Instead of:

```python
if attempts > 3:
```

consider:

```python
MAX_LOGIN_ATTEMPTS = 3

if attempts > MAX_LOGIN_ATTEMPTS:
```

This makes the meaning explicit and makes future changes safer.

## 18. Keep Database Access Predictable

Watch for:

- N+1 queries
- Unnecessary queries
- Missing indexes
- Unbounded queries
- Missing transactions
- Inconsistent error handling

Don't assume database operations are cheap.

For expensive or critical queries, inspect the query plan and measure actual performance.

## 19. Log Useful Information—Safely

Logs should help diagnose problems.

Good logs provide:

- timestamp
- operation
- request/correlation ID
- relevant resource ID
- result
- error context

Never log sensitive information such as:

- passwords
- API keys
- authentication tokens
- credit-card information
- private credentials

Be particularly careful with request bodies and authorization headers.

## 20. Use Consistent Project Structure

A predictable structure reduces cognitive overhead.

For example:

```
src/
  api/
  services/
  models/
  repositories/
  utils/

tests/
docs/
scripts/
```

The exact structure matters less than consistency.

## 21. Keep CI Strict

Your CI pipeline should ideally catch problems before code reaches production.

A basic pipeline might be:

```
Install dependencies
        ↓
Format check
        ↓
Lint
        ↓
Unit tests
        ↓
Integration tests
        ↓
Build
        ↓
Security/dependency checks
```

A pull request shouldn't be considered ready merely because the application runs locally.

## 22. Review Your Own Code Before Opening a PR

Before asking someone else to review your code:

```bash
git diff
```

Then ask yourself:

- Did I accidentally include unrelated changes?
- Are there debugging statements?
- Did I leave dead code?
- Are errors handled?
- Are secrets exposed?
- Are tests included?
- Is the naming clear?
- Can this be simplified?
- Did I introduce unnecessary dependencies?

Self-review often catches the easiest problems.

## 23. Refactor Incrementally

Don't wait until the codebase becomes a disaster.

When touching an area of code:

1. Understand the existing behavior.
2. Add or improve tests.
3. Make the smallest safe change.
4. Run tests.
5. Refactor if necessary.
6. Review the diff.
7. Commit the logical change.

Avoid combining a huge refactor with a major feature unless there is a strong reason.

## 24. Measure Before Optimizing

Don't assume something is slow.

Use:

- profilers
- metrics
- tracing
- database query analysis
- benchmarks

Then optimize the actual bottleneck.

Readable code is usually preferable to highly optimized code whose performance benefit hasn't been demonstrated.

## 25. Automate Repetitive Hygiene

The best hygiene practices are the ones developers don't have to remember manually.

Consider automating:

- formatter
- linter
- type checker
- tests
- secret scanning
- dependency scanning
- pre-commit checks
- CI validation

A good principle is:

> If a mistake can be detected automatically, don't rely exclusively on human memory to detect it.

## A Practical Daily Workflow

For everyday development, use this cycle:

1. Pull the latest changes
2. Create a focused branch
3. Understand the existing code
4. Make a small change
5. Format
6. Lint/type-check
7. Run relevant tests
8. Review the diff
9. Commit a logical change
10. Push and let CI validate it

## Before You Commit

Use this quick checklist:

- [ ] Code is formatted
- [ ] Linter passes
- [ ] Type checker passes, if applicable
- [ ] Relevant tests pass
- [ ] New behavior has tests where appropriate
- [ ] No debugging code remains
- [ ] No secrets are included
- [ ] No unnecessary files are included
- [ ] Error handling is appropriate
- [ ] Names are clear
- [ ] Unused code/imports are removed
- [ ] Git diff contains only the intended changes
- [ ] Commit message describes the actual change

## The Golden Rules

If you remember only a few things:

1. Keep it simple.
2. Make names communicate intent.
3. Keep functions and modules focused.
4. Don't duplicate business logic unnecessarily.
5. Validate external input.
6. Handle errors explicitly.
7. Never commit secrets.
8. Write tests for important behavior and bugs.
9. Automate formatting, linting, and testing.
10. Review your diff before committing.
11. Prefer small, reversible changes.
12. Measure before optimizing.

Good code hygiene isn't about following every rule rigidly. It's about making the codebase easy for the next person—including future you—to safely understand and modify.
