# Security Policy

## Reporting a Vulnerability

Do not open public issues for suspected vulnerabilities.

Report vulnerabilities to:

**security@locktivity.com**

Please include:
- Description of the vulnerability
- Steps to reproduce
- Affected action version or commit
- Potential impact and attacker prerequisites
- Minimal proof-of-concept, logs, or payloads when possible

## Response Timeline

- Initial triage acknowledgement: within 48 hours
- Severity assessment: within 7 days
- Remediation target:
  - Critical: 7 days
  - High: 30 days
  - Medium/Low: next planned release or documented risk acceptance

## Scope

This policy covers:
- `action.yml` and the scripts in `scripts/`
- This repository's release workflow and the tags it publishes and moves
- How the action handles the workflow's GitHub ID tokens and Locktivity's sign-in response

## Out of Scope

- Vulnerabilities in epack itself. Report those under [epack's security policy](https://github.com/locktivity/epack/blob/main/SECURITY.md).
- Vulnerabilities in GitHub, GitHub-hosted runners, or the actions this action uses, with no exploitable path through this action
- Reports without actionable reproduction details
- Social engineering, phishing, or physical access attacks

## Safe Harbor

If you follow this policy in good faith, we will not pursue legal action for your research.
Testing must:

- Avoid privacy violations and data destruction
- Avoid service disruption
- Use only accounts/systems you own or have explicit permission to test

## Disclosure

We follow coordinated disclosure.

- Do not publish details until a fix or mitigation is available.
- We may request an embargo period to protect users.
- After release, we will credit researchers who want attribution.
