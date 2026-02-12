# Rollback Strategy

How to rollback production when a deployment causes issues.

## Quick Rollback (Cloudflare Pages)

**Expected recovery time: < 2 minutes**

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/) → **Workers & Pages**
2. Select **event-hub** (prod project)
3. Open the **Deployments** tab
4. Find the previous working deployment in the list
5. Click the **⋮** menu on that deployment
6. Select **Rollback to this deployment** or **Promote to Production**

The previous deployment becomes live immediately. No rebuild required.

## Checklist Before Rollback

- [ ] **Confirm the issue is app-level** — not DNS, CDN, or Firebase outage
- [ ] **Confirm dev is working** — if dev (events-dev.aisaiah.org) has the same issue, it may be a shared backend problem
- [ ] **Capture logs** — browser console, network tab, or any error reports
- [ ] **Note the bad deployment** — commit hash or deployment ID for later investigation

## After Rollback

1. **Investigate** — reproduce the issue locally or on dev
2. **Fix** — make the fix on a feature branch
3. **Test** — merge to dev, verify on events-dev.aisaiah.org
4. **Redeploy** — merge to main when ready

## Release Tagging Recommendation

Tag releases on main for easier rollback reference:

```bash
git tag -a v1.2.3 -m "Release 1.2.3 - March Cluster RSVP"
git push origin v1.2.3
```

Use semantic versioning (MAJOR.MINOR.PATCH). When rolling back, you can identify which tag corresponds to the working deployment.

## Limitations

- **Firestore data**: Rollback only reverts the deployed app. Any data written to Firestore by the bad deployment remains. Handle data migration separately if needed.
- **Build artifacts**: Cloudflare keeps deployment history. Older deployments are available for rollback until they expire (check Cloudflare limits).
