# Branch Protection Strategy

This document describes the required GitHub branch protection settings and deployment flow for Event Hub.

## Deployment Flow

```
feature/* → dev → main
```

1. **feature branches** — developers work on feature branches (e.g. `feature/rsvp-update`)
2. **dev** — merge feature branches via PR; deploys to event-hub-dev (events-dev.aisaiah.org)
3. **main** — merge dev via PR when ready for production; deploys to event-hub (events.aisaiah.org, rsvp.aisaiah.org)

## Cloudflare Pages Mapping

| Branch | Cloudflare Project | Custom Domain |
|--------|--------------------|---------------|
| **dev** | event-hub-dev | events-dev.aisaiah.org |
| **main** | event-hub | events.aisaiah.org, rsvp.aisaiah.org |

## Required GitHub Settings

### Branch: main

Configure in **Settings** → **Repository** → **Branches** → **Add branch protection rule** (or edit existing):

| Setting | Value | Purpose |
|---------|-------|---------|
| **Require a pull request before merging** | On | Prevents direct pushes |
| **Require approvals** | At least 1 | Enforces review |
| **Require status checks to pass** | On | Build must pass |
| **Require branches to be up to date** | On | Must merge latest before deploy |
| **Do not allow bypassing the above settings** | On | Applies to all users |
| **Allow force pushes** | Off | Prevents history rewrite |
| **Restrict who can push** | Optional | Limit direct pushes to admins |

### Branch: dev

| Setting | Value | Purpose |
|---------|-------|---------|
| **Require a pull request before merging** | Optional | Recommended from feature/* |
| **Require status checks to pass** | On | Build must pass |
| **Allow force pushes** | Off | Prevents history rewrite |

## Deployment Flow Detail

1. **Development**: Create feature branch from `dev`, make changes, open PR to `dev`.
2. **Dev deployment**: On merge to `dev`, GitHub Actions deploys to event-hub-dev with ENV=dev.
3. **Production release**: When dev is stable, open PR from `dev` to `main`. After review and merge, GitHub Actions deploys to event-hub with ENV=prod.
4. **No direct pushes to main**: All production changes flow through dev first.

## Safety Guarantees

- **Dev never deploys to prod**: Different Cloudflare projects.
- **Prod never uses ENV=dev**: CI sets ENV from branch only.
- **No accidental prod**: Branch protection requires PR and approval.
