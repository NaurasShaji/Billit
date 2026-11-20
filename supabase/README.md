# Supabase setup for Billit

This branch starts the Supabase integration from a clean copy of `main`.

## Architecture

- SQLite remains the local database and offline source of truth.
- Supabase is the shared cloud and synchronization target.
- One Supabase project serves all shops.
- Every shop-owned record is scoped by `shop_id`.
- Supabase Auth identifies users; the local Billit username/password table is not a cloud identity provider.
- PostgreSQL Row Level Security (RLS) is mandatory. Never ship a service-role key in a Flutter app.

## First migration

Apply both migrations in numeric order to a new Supabase project using the Supabase SQL Editor or Supabase CLI:\n1. `migrations/202611200001_initial_multi_tenant_schema.sql`\n2. `migrations/202611200002_auth_profiles_and_worker_permissions.sql`

The migration creates:
- Profiles and platform-owner flag
- Shops and shop memberships
- Products, sales, sale items, expenses and employees
- Shop settings and audit logs
- Per-shop RLS policies and role helper functions

## Roles

- Platform owner: centralized control over shops and user membership.
- Shop admin: manages their shop and its workers.
- Worker: feature-scoped access controlled by the `permissions` JSONB on their shop membership. Defaults allow billing and inventory access, while reports, expenses and payroll are disabled. Workers can create sales when billing is enabled; product and other business-data mutations remain admin-only.

The platform-owner flag must only be assigned from a trusted administrative context. Never expose an update path that lets a normal user set it. The Auth trigger creates a non-privileged profile automatically; bootstrap the first owner by creating their Auth account, then setting `profiles.is_platform_owner = true` for that user's UUID in the SQL editor.

## Important setup note

The SQL migration intentionally does not create a public sign-up flow or automatically trust user metadata. The next implementation step is a trusted account-provisioning flow that creates Auth users, profile rows, shop memberships and audit events. The first platform owner must be bootstrapped manually in the Supabase dashboard/SQL editor.

## Not implemented yet

- Flutter Supabase client dependency and optional client initialization are now added. Supply `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` at build time; without them, the app remains in local mode.
- The sign-in screen has been redesigned, but it still authenticates against the existing local SQLite accounts. Cloud login and trusted account provisioning
- SQLite initial upload
- Background/two-way sync, retry queue and tombstone handling
- Conflict resolution and sync UI

Do not connect production data until these are implemented and tested.
