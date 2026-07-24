# Admin API Firebase Functions

Trusted backend for the Journal Trend Analyzer admin website. It exports one Firebase Functions v2 HTTPS function, `adminApi`, from `asia-southeast1` on Node.js 22.

## Security model

- Every `/api/v1/**` request requires `Authorization: Bearer <Firebase ID token>`.
- Tokens are checked with `verifyIdToken(token, true)`, including revocation, and must contain the custom claim `admin: true`.
- Set `ENFORCE_APP_CHECK=true` to additionally require `X-Firebase-AppCheck`.
- CORS accepts same-origin requests plus `localhost`/`127.0.0.1` development origins.
- API responses use `Cache-Control: private, no-store`, `X-Content-Type-Options: nosniff`, and a validated/generated `X-Request-Id`.
- Service-account credentials are only loaded through Application Default Credentials. Never put them in the browser bundle or repository.

Successful JSON responses use:

```json
{ "data": {}, "requestId": "..." }
```

JSON errors use:

```json
{ "error": { "code": "...", "message": "..." }, "requestId": "..." }
```

`GET /reports/download` is the intentional exception: on success it streams an inline PDF; failures still use the JSON error envelope.

## Configuration

Copy `.env.example` to the Firebase project-specific Functions environment file used for deployment and set values as needed:

| Parameter | Purpose |
|---|---|
| `ENFORCE_APP_CHECK` | Require App Check on top of Firebase Auth. Defaults to `false` until the web app is registered. |
| `ADMIN_ALLOWED_ORIGINS` | Exact comma-separated Hosting origins accepted through the rewrite proxy. Defaults to the admin site's `.web.app` and `.firebaseapp.com` domains. Add custom domains explicitly. |
| `GA4_PROPERTY_ID` | Numeric GA4 property ID used to auto-discover the `analytics_<PROPERTY_ID>` BigQuery dataset. |
| `CRASHLYTICS_TABLE` | Fully qualified `project.dataset.table` from the Crashlytics BigQuery export. |

The runtime identity needs least-privilege access for Firebase Auth user administration, Remote Config, Storage objects, FCM send, Firestore audit logs, Analytics reporting, and (when configured) BigQuery jobs/data viewing. Firestore must be initialized before audit logs can be queried. Audit write failures are logged but never roll back the completed admin action.

## Routes

All routes are below `/api/v1`:

| Method and route | Behavior |
|---|---|
| `GET /me` | Current canonical Auth profile and admin state. |
| `GET /overview` | Full Auth/report scans and current Remote Config version. |
| `GET /users` | Paginated users or exact UID/email lookup. |
| `PATCH /users/:uid` | Update display name, email, verification, or disabled state. |
| `PUT /users/:uid/role` | Grant/revoke `admin` while preserving all other custom claims. Demotion revokes sessions. |
| `POST /users/:uid/revoke` | Revoke all refresh tokens. |
| `DELETE /users/:uid` | Delete a user. |
| `GET /remote-config` | Current ETag, version, Lab values, and all parameters. |
| `PUT /remote-config` | Publish `max_journals`/`max_keywords` (integers 1–100) with optimistic ETag checking while preserving unrelated template data. |
| `GET /remote-config/versions` | The 20 most recent versions by default; returns a next-page token for future pagination. |
| `POST /remote-config/rollback` | Publish a retained version with required `expectedEtag` optimistic concurrency. |
| `GET /reports` | Paginated `report/` PDFs with owner email and object generation. |
| `GET /reports/download?path=...` | Validate and stream a PDF inline (exact path layout, PDF MIME, at most 10 MiB). |
| `DELETE /reports` | Delete one strictly validated report path only when its required `generation` still matches. |
| `POST /messages/test` | Send to one pasted FID or legacy registration token. The full target is never logged. |
| `GET /analytics?days=7|30|90` | GA4 summary, exact seven Lab events, and daily trend. |
| `GET /crashes?days=7|30|90` | Crashlytics BigQuery summary, issues, and daily fatal/non-fatal trend. |
| `GET /audit-logs` | Recent mutation audit records. |

Self-disable, self-delete, and self-demotion are denied. Disabling, deleting, or demoting the last active admin is also denied. Direct changes made outside this API (for example in Google Cloud Console) are outside these safeguards.

Analytics and Crashlytics return a stable integration state (`ready`, `pending`, `unconfigured`, or `error`) with empty arrays/summaries when data is not yet available, so the admin UI can distinguish the first BigQuery export from missing configuration or a runtime error.

## Bootstrap the first admin

Authenticate Application Default Credentials, then run exactly one selector:

```powershell
npm run set-admin -- --email admin@example.com --project journal-trend-analyzer
npm run set-admin -- --uid FIREBASE_UID --project journal-trend-analyzer
npm run set-admin -- --email admin@example.com --revoke --project journal-trend-analyzer
```

`--project` is mandatory so the bootstrap command cannot grant the admin claim in an unintended Firebase project.

The script preserves unrelated claims, protects the last active admin on revoke, revokes existing sessions after both grant and revoke, and attempts a Firestore audit record. There is deliberately no self-bootstrap HTTP endpoint.

## Development checks

Use Node 22 (`.nvmrc`), then run:

```powershell
npm ci
npm run lint
npm run typecheck
npm test
npm run build
```

The deploy entrypoint is `lib/index.js`; tests are not emitted into `lib`.

## Operational limitations

- User-targeted FCM campaigns are not available because the existing Flutter app does not persist a UID-to-FID/token mapping. This API only sends to a pasted target.
- Crash and Analytics data require their Firebase BigQuery exports. The adapters auto-discover exported datasets/tables and prefer completed daily GA4 tables over intraday duplicates.
- Crashlytics `affectedUsers` is calculated from distinct installation UUIDs because the mobile app does not set a Crashlytics Auth user identifier.
- `/overview` intentionally performs complete Auth and report scans for accurate counts; for very large projects, replace this with maintained aggregate counters.
- Remote Config changes are subject to the mobile app's five-minute minimum fetch interval.
- The unchanged Flutter apps call `getDownloadURL()` for report objects. Any Firebase download-token URL is a bearer URL and remains usable if shared, independently of Storage Rules, until that object's token is rotated or the object is deleted. The Admin Web derives preview URLs from each object's current metadata instead of hard-coding a bucket, host, token, or object path.
- Firebase Storage Rules do not expose the new object's standard `contentEncoding` field in `request.resource`, so they cannot validate it at upload time. The Admin API therefore rejects encoded legacy/current objects, pins the validated object generation, and disables automatic stream decompression.
