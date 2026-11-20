# Billit Supabase integration

This branch contains cloud authentication, account provisioning, tenant-isolated local storage and incremental two-way synchronization with optimistic conflict protection. It is intentionally separate from `main`.

## Architecture

- One Supabase project serves multiple shops.
- Supabase Auth is the cloud identity provider.
- `profiles` stores platform-owner identity; `shop_memberships` maps users to shops and roles.
- Every business table is scoped by `shop_id` and protected by PostgreSQL Row Level Security (RLS).
- Platform owner manages shops and shop administrators.
- Shop administrators create workers and set feature permissions.
- SQLite remains the local database for the existing offline app.
- Never include the Supabase service-role key in Flutter or any client build.

## Implemented in this branch

- Optional Supabase Flutter initialization using build-time URL and publishable key.
- Email/password sign-in through Supabase Auth when cloud configuration is present.
- Local username/password login remains available when Supabase is not configured.
- No default demo admin/worker accounts are seeded in cloud-configured builds.
- Supabase password reset email flow and Android/iOS callback registration.
- Profile and shop-membership lookup after sign-in.
- Platform-owner shop selection support.
- Account Management screen:
  - Platform owner creates a shop and its first shop-admin account.
  - Shop admin creates worker accounts with feature permissions.
  - Admins list shop members, update worker permissions and disable worker memberships.
- Trusted `manage-account` Edge Function creates Auth users; the service-role key stays server-side.
- Worker permission defaults: billing and inventory enabled; reports, expenses and payroll disabled.
- Home navigation is permission-aware.
- Each cloud shop has its own SQLite file on native platforms or IndexedDB namespace on web. The original `billit.db` remains separate.
- SQLite schema v3 includes a durable coalescing outbox, deletion tombstones, revision-safe acknowledgements, persistent retry deadlines with exponential backoff, and a single coalesced outbox entry for shop settings.
- Two-way sync covers products, sales and sale items, expenses, employees and administrator-managed shop settings. Pulls use a server-side watermark, persisted per-table cursors, timestamp/ID keyset pagination and a short replay overlap. Changed sales are downloaded with their complete line-item snapshots.
- Remote writes are applied without re-enqueuing them; dirty local records are never overwritten by pulls. Cloud versions are stored locally, uploads use compare-and-swap checks, and conflicts require an explicit Keep this device / Use cloud version choice.
- Shop admins can explicitly import existing device data into an empty shop after a count preview and confirmation. Sale references are validated and the original local records are retained.
- SQL security hardening: shop-scoped sale-item/product references, constrained permission JSON, protected membership identity fields and explicit Data API grants behind RLS.
- Billing-only workers can synchronize stock changes from sales, but a database trigger prevents them from editing product master fields.

## Important limitation: sync is not production-ready

Cloud authentication, tenant-local database separation, durable outbox, incremental two-way sync, foreground automatic retry and explicit conflict resolution are implemented in source. This is not production-ready: OS-level background scheduling while the app is closed, live multi-device testing, remaining ancillary data sync and live-project integration tests remain outstanding.

For that reason, when Supabase is configured, Billit deliberately blocks access to the normal POS screens after cloud sign-in. The local tenant files and cloud sync path are implemented, but OS-level background scheduling, concurrent-device verification and live RLS validation remain incomplete. Shop settings are synchronized with the same version checks as other cloud data. **Do not remove this guard or use cloud accounts for live billing until those remaining controls are completed and tested.**

## SQL migrations

Apply these files in this exact order to a new Supabase project:

1. `migrations/202611200001_initial_multi_tenant_schema.sql`
2. `migrations/202611200002_auth_profiles_and_worker_permissions.sql`
3. `migrations/202611200003_security_hardening.sql`
4. `migrations/202611200004_data_api_grants.sql`
5. `migrations/202611200005_permission_policy_alignment.sql`
6. `migrations/202611200006_worker_sync_permissions.sql`
7. `migrations/202611200007_billing_stock_sync.sql`
8. `migrations/202611200008_restrict_helper_function_execution.sql`
9. `migrations/202611200009_atomic_sale_snapshot_sync.sql`
10. `migrations/202611200010_keyset_sale_item_pull.sql`
11. `migrations/202611200011_incremental_sync_watermark.sql`
12. `migrations/202611200012_compare_and_swap_sale_sync.sql`

The migrations create profiles, shops, memberships, products, sales, sale items, expenses, employees, shop settings, audit logs, helper functions and RLS policies. The helper-function migration revokes default PUBLIC/anon execution on the security-definer authorization helpers. The sale-sync migration adds an authenticated, RLS-respecting RPC that writes a sale and replaces its line items in one database transaction, avoiding partially uploaded sales. The keyset-pagination migration adds RLS-respecting sale-item paging. Migration 011 provides a database-server timestamp watermark so concurrent writes are deferred safely to the next incremental pull. Migration 012 replaces the sale snapshot RPC with a compare-and-swap version check so concurrent edits cannot silently overwrite each other.

## Edge Function

Deploy the account-provisioning function from the repository root:

```bash
supabase functions deploy manage-account
```

The function uses the platform-provided `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` environment variables. It verifies the caller's JWT and checks platform-owner/shop-admin privileges before provisioning accounts. Do not expose the service-role key to Flutter.

## First platform owner

The first platform owner is bootstrapped manually:

1. Create the owner's email/password account under Supabase Authentication > Users.
2. Copy that user's Auth UUID.
3. In the SQL Editor, set `profiles.is_platform_owner = true` for that UUID.
4. The owner can then sign in to Billit and create the first shop and its administrator.

The Auth trigger creates a non-privileged profile for each new Auth user. Never set platform-owner status from client metadata or a public sign-up flow.

## Authentication redirect

Android and iOS are registered for this callback:

`com.naurasshaji.billit://login-callback`

Add that exact URL under Supabase Authentication > URL Configuration > Redirect URLs. For web builds, configure the deployed Billit web URL as the Site URL/allowed redirect as appropriate.

## Flutter build configuration

Use the project's URL and publishable key (not the secret/service-role key):

```bash
flutter pub get
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Without these defines, the app uses its existing local-only authentication path.

## Remaining engineering work before production use

- OS-level background scheduling while the app is closed.
- Live multi-device conflict testing for every synchronized table and role.
- Synchronization of remaining ancillary records beyond shop settings.
- Full SQL/RLS integration tests against a real Supabase project.
- End-to-end verification of shop setup, data import, worker permissions and offline/multi-device workflows.

Do not use production business data until these items are completed and tested.
