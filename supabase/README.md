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

Apply `migrations/202611200001_initial_multi_tenant_schema.sql` to a new Supabase project using the Supabase SQL Editor or Supabase CLI.

The migration creates:
- Profiles and platform-owner flag
- Shops and shop memberships
- Products, sales, sale items, expenses and employees
- Shop settings and audit logs
- Per-shop RLS policies and role helper functions

## Roles

- Platform owner: centralized control over shops and user membership.
- Shop admin: manages their shop and its workers.
- Worker: read access to shop data in the initial policy baseline. Write permissions should be granted feature-by-feature after the app's worker permissions are mapped.

The platform-owner flag must only be assigned from a trusted administrative context. Never expose an update path that lets a normal user set it.

## Important setup note

The SQL migration intentionally does not create a public sign-up flow or automatically trust user metadata. The next implementation step is a trusted account-provisioning flow that creates Auth users, profile rows, shop memberships and audit events. The first platform owner must be bootstrapped manually in the Supabase dashboard/SQL editor.

## Not implemented yet

- Flutter Supabase client initialization
- Cloud login and account provisioning
- SQLite initial upload
- Background/two-way sync, retry queue and tombstone handling
- Conflict resolution and sync UI

Do not connect production data until these are implemented and tested.
