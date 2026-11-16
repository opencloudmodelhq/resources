# Contributing

Thank you for helping.

## Before you start

Open an issue first for anything bigger than a typo, so we can agree on the approach.

## How we work

- **Every placement cites a source.** Each vendor placement in `data/mapping.csv` names the primary source
  it was checked against.
- **Stable identifiers.** A `concept_id` is never reused or renumbered. Retire a concept; do not delete it.
- **Verified rows only.** A row enters `data/` only after a person has verified it.
- **Conventional Commits** for every commit message, for example `data: verify subnet placements`.

## Merges

Pull requests are merged by squash, with linear history: one signed commit per pull request reaches `main`.

## Sign your work (DCO)

Every commit needs a `Signed-off-by` line certifying the
[Developer Certificate of Origin](https://developercertificate.org/):

```sh
git commit -s
```

Contributions are accepted under the licence of the files they change (see `REUSE.toml`).

## Authorship

You are the author of what you submit and you are responsible for every line.

- Only a human may add `Signed-off-by`.
- Say in the pull request which tools wrote any part of the change.
- Unsolicited bulk or fully generated pull requests will be closed.
- **Data**: every value you add must trace to a primary source you cite. A model's recollection is
  not a source.

## Data and sources

Public sources only: no NDA, login-gated, paywalled, scraped or leaked material.

## Security

Never report a vulnerability in an issue. See SECURITY.md.
