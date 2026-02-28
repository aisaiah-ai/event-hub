# Fix API 500 / PERMISSION_DENIED on Firestore

If **GET /api/v1/events** (or other API endpoints that read Firestore) returns:

```json
{"ok":false,"error":{"code":"internal","message":"7 PERMISSION_DENIED: Missing or insufficient permissions."}}
```

the **Cloud Functions service account** does not have permission to read Firestore.

## Fix in Google Cloud Console

1. Open **Google Cloud Console** → project **aisaiah-event-hub**.
2. Go to **IAM & Admin** → **IAM**.
3. Find the principal **App Engine default service account**  
   (`aisaiah-event-hub@appspot.gserviceaccount.com`).  
   (Or search for `@appspot.gserviceaccount.com`.)
4. Ensure it has one of:
   - **Cloud Datastore User** (read/write Firestore), or
   - **Editor** (broader, includes Firestore).
5. If it has neither, click **Edit** (pencil) → **Add another role** → **Cloud Datastore User** → Save.

## Fix with gcloud

Grant **Cloud Datastore User** to both identities Cloud Functions may use:

```bash
PROJECT_ID=aisaiah-event-hub

# 1) App Engine default (usual for 1st gen Functions)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com" \
  --role="roles/datastore.user"

# 2) Compute Engine default (used by some runtimes)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/datastore.user"
```

**Check which account your function uses:** Firebase Console → **Functions** → select **api** → **Configuration** (or Google Cloud Console → **Cloud Functions** → **api** → **Details**) and look at **Runtime service account**.

After applying the role, wait 1–2 minutes and retry **GET /api/v1/events**.

## If it still fails

1. **Confirm the runtime account:** In Cloud Console → **Cloud Functions** → **api** → **Details**, note the **Runtime service account**. Grant **Cloud Datastore User** to that exact principal in **IAM & Admin** → **IAM**.
2. **Confirm Firestore database:** The API uses the **default** Firestore database. If your data is in a named database (e.g. `event-hub-dev`), the API code must be updated to use that database; the IAM role alone will not fix it.
3. **Propagation:** IAM can take a few minutes. Retry after 5 minutes or redeploy the function once to force a fresh cold start.
