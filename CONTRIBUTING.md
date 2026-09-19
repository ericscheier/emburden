# Contributing to emburden

Thanks for considering a contribution. `emburden` is part of the
open-source **emburden** ecosystem at
[emburden.org](https://emburden.org), stewarded for public release by
the **Emergi Foundation**
([github.com/emergi-foundation](https://github.com/emergi-foundation)).

**Canonical contribution policy** lives at the Foundation:
[emergi-foundation/.github/CONTRIBUTING.md](https://github.com/emergi-foundation/.github/blob/main/CONTRIBUTING.md).
This file carries only the `emburden`-specific dev-setup and style notes
on top of that policy.

## Contact and license

- General correspondence: `info@emburden.org`.
- Foundation: `info@emrgi.org`.
- Security disclosures: `security@emrgi.org` (private).
- License: **AGPL-3.0-or-later** (see `LICENSE`). Contributions are
  accepted under the same license via the DCO sign-off convention (no
  CLA, no copyright assignment).

## How to contribute

Three tracks, in order of scope:

1.  **Bug reports** at the issue tracker: describe the observed vs
    expected behavior, minimal reproducer, R session info
    ([`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html)), and
    the affected version. Search open + closed issues first.
2.  **Feature suggestions** at the issue tracker with the `enhancement`
    label. Include the underlying research question the feature would
    answer, not just the API you’d like.
3.  **Pull requests** for code, documentation, tests, or data-loader
    additions. Open an issue first for anything beyond a small fix so we
    can align on scope before you invest time.

## Development

Standard R package workflow: `devtools::load_all()`, `devtools::test()`,
`devtools::check()`. Some pipelines depend on cached external data under
`~/.cache/emburdendata/`; see individual `download_*()` docstrings for
provisioning. A working `emburden` ecosystem checkout (sibling packages
`emburdendata`, `emburdengeo`, `emburdenstats`, `emburdenutil`,
`emburdenweather`, `emburdenhealth`, `emburdenvis`, etc.) is required
for most integration paths.

## Style

- Follow the tidyverse style guide for R.
- Snake_case for functions, columns, variables.
- Comments in code only where the *why* is non-obvious. Well-named
  functions and clear code are preferred to running commentary.
- Public functions carry roxygen documentation with `@examples` and a
  `\dontrun{}` block for network- or cache-dependent examples.
- Tests live under `tests/testthat/` and follow the existing
  `test-<module>.R` naming.

## Attribution and naming policy

- **Commit-message attribution** for AI coding-assistant collaboration
  (Claude Code and similar) is **not** included on commits going
  forward, per project policy set on 2026-09-19. The overall
  AI-collaboration disclosure lives at `AUTHORS.md`; per-commit tags are
  considered redundant given that project-level disclosure.
- **Named individuals** (project maintainers, external collaborators)
  are **not** listed in code, documentation, commit messages, or
  rendered publications by default. Contributors who want personal
  attribution can request it at `info@emburden.org` and it will be added
  to `AUTHORS.md`; the default is role-based (“emburden project”,
  “external reviewer”, “external collaborator”) which keeps the public
  surface impersonal and stable across staff changes.
- **Scholarly citations** (Odum, Deming and Stephan, Hruschka et al.,
  etc.) are exempt from the naming policy; citing published methods by
  author is the norm and required for academic legibility.
- **`git log`** contains the raw commit-author record and is
  authoritative for who contributed which lines. `AUTHORS.md` is the
  human-readable summary and may aggregate contributors under role
  labels.

## Contributor Certificate of Origin

We use the [Developer Certificate of
Origin](https://developercertificate.org/) convention: by opening a pull
request you certify that you have the right to submit the contribution
under the project license. No separate CLA. `git commit -s` (sign-off)
is welcomed but not required.

## Ecosystem-wide policy

The ecosystem uses a three-tier hosting model:

- **Dev**: `ScheierVentures/*` (private) — working repos.
- **Mirror**: `ericscheier/*` (public) — where you’re reading this.
  External collaborators track this tier.
- **Release**: `emergi-foundation/*` (public) — tagged versions, citable
  via DOI.

Cross-cutting policies (publication workflow, per-release quality gate,
gated-data handling, attribution + naming policy, release cadence) live
in
[emburden-site/docs/PRIVATE_TO_PUBLIC.md](https://github.com/ericscheier/emburden-site/blob/master/docs/PRIVATE_TO_PUBLIC.md).

Contributing to this repo (at Mirror tier) enters the ecosystem via the
standard PR flow. Contributions land on Mirror first, sync to Dev
privately, and reach Release on the next tagged version.
