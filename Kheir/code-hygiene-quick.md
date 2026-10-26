# Code Hygiene — Quick Reference

Full guide: `docs/code-hygiene.md`

## Before You Commit

- Code is formatted
- Linter passes
- Type checker passes, if applicable
- Relevant tests pass
- New behavior has tests where appropriate
- No debugging code remains
- No secrets are included
- No unnecessary files are included
- Error handling is appropriate
- Names are clear
- Unused code/imports are removed
- Git diff contains only the intended changes
- Commit message describes the actual change

## Golden Rules

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
