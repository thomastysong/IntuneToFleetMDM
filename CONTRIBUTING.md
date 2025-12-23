# Contributing

Thanks for your interest in contributing!

## Development prerequisites

- Windows 10/11
- PowerShell 5.1+

## Local development

Import the module directly from the repo (no install required):

```powershell
Import-Module .\IntuneToFleetMDM\IntuneToFleetMDM.psd1 -Force
Get-Command -Module IntuneToFleetMDM
```

## Testing

This repo does not require a Fleet API token for unit testing. Most behavior can be validated by:

- Verifying parsing and registry read functions
- Running `Invoke-ITFMDMMigration -WhatIf` to ensure flows and logging behave without changing device state

If you add Pester tests, place them under `tests/` and keep them PowerShell 5.1 compatible.

## Pull requests

- Keep changes focused and well described.
- Do not include secrets (API keys, tokens, node keys) in code, tests, logs, or screenshots.
- If you change enrollment/verification behavior, include a short note in `docs/Design-notes.md`.


