# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

We take the security of Kheir seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

1. **Do NOT open a public issue.** Security vulnerabilities must be reported privately.
2. Use [GitHub's private vulnerability reporting](https://github.com/devabdullahi/Kheir-App/security/advisories/new) to submit your report.
3. Alternatively, email: **security@kheir.app** (replace with your actual contact).

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Acknowledgment:** Within 48 hours
- **Initial assessment:** Within 1 week
- **Fix timeline:** Depends on severity, typically within 30 days

### Scope

In scope:
- iOS application code
- API integrations
- Data handling and storage
- Authentication and authorization

Out of scope:
- Third-party services we integrate with (report to them directly)
- Social engineering attacks
- Denial of service attacks

## Security Practices

- All dependencies are monitored via Dependabot
- CodeQL static analysis runs on every PR and weekly
- Secret scanning and push protection are enabled
- Branch protection requires PR review before merge
