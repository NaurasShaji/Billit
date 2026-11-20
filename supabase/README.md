# Billit Supabase integration

This branch contains the cloud-authentication and account-provisioning foundation. It is intentionally separate from `main`.

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
- Trusted `manage-account` Edge Function creates Auth users; the service-role key stays server-side.
- Worker permission defaults: billing and inventory enabled; reports, expenses and payroll disabled.
- Home navigation is permission-aware.
- SQL security hardening: shop-scoped sale-item/product references, constrained permission JSON, protected membership identity fields and explicit Data API grants behind RLS.

## Important limitation: business-data sync is not implemented

Cloud authentication and account provisioning are implemented, but SQLite-to-Supabase synchronization, per-shop local database isolation, conflict handling, retry queues and tombstones are not implemented yet.

For that reason, when Supabase is configured, Billit deliberately blocks access to the normal POS screens after cloud sign-in. This prevents one shop from accidentally seeing another shop's unsynchronized local SQLite data. **Do not remove this guard or use cloud accounts for live billing until tenant-isolated storage and synchronization are completed and tested.**

## SQL migrations

Apply these files in this exact order to a new Supabase project:

1. `migrations/202611200001_initial_multi_tenant_schema.sql`
2. `migrations/202611200002_auth_profiles_and_worker_permissions.sql`
3. `migrations/202611200003_security_hardening.sql`
4. `migrations/202611200004_data_api_grants.sql`

The migrations create profiles, shops, memberships, products, sales, sale items, expenses, employees, shop settings, audit logs, helper functions and RLS policies.

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

- Per-shop local SQLite isolation and safe first-run migration of existing local data.
- Initial upload of existing products, sales, expenses and employees.
- Two-way sync with an outbox, idempotency, conflict resolution and retry handling.
- Sync status UI, offline recovery and deletion tombstones.
- Automated Flutter tests and SQL/RLS integration tests against a real Supabase project.
- Automated Flutter tests and SQL/RLS integration tests against a real Supabase project.

Do not use production business data until these items are completed and tested.
