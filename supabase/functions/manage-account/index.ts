import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const defaultPermissions = {
  billing: true,
  inventory: true,
  reports: false,
  expenses: false,
  payroll: false,
};

function validEmail(value: unknown): value is string {
  return typeof value === "string" &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());
}

function validPassword(value: unknown): value is string {
  return typeof value === "string" && value.length >= 8;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceRoleKey) {
    return json({ error: "Server configuration is incomplete" }, 500);
  }

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "Authentication required" }, 401);
  }

  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const adminClient = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: authData, error: authError } = await callerClient.auth.getUser();
  if (authError || !authData.user) return json({ error: "Invalid session" }, 401);
  const callerId = authData.user.id;

  const { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .select("is_platform_owner")
    .eq("id", callerId)
    .maybeSingle();
  if (profileError || !profile) return json({ error: "Account profile not found" }, 403);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const action = body.action;
  const isOwner = profile.is_platform_owner === true;

  if (action === "create_shop") {
    if (!isOwner) return json({ error: "Platform owner access required" }, 403);
    const shopName = typeof body.shop_name === "string" ? body.shop_name.trim() : "";
    const email = typeof body.admin_email === "string" ? body.admin_email.trim().toLowerCase() : "";
    const password = body.admin_password;
    if (!shopName || shopName.length > 120 || !validEmail(email) || !validPassword(password)) {
      return json({ error: "Provide a shop name, valid admin email, and password of at least 8 characters" }, 400);
    }

    const created = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: String(body.admin_name ?? "").trim().slice(0, 120) },
    });
    if (created.error || !created.data.user) {
      return json({ error: created.error?.message ?? "Could not create admin account" }, 400);
    }

    const shop = await adminClient.from("shops").insert({
      name: shopName,
      business_email: email,
    }).select("id, name").single();
    if (shop.error || !shop.data) {
      await adminClient.auth.admin.deleteUser(created.data.user.id);
      return json({ error: shop.error?.message ?? "Could not create shop" }, 500);
    }

    const membership = await adminClient.from("shop_memberships").insert({
      shop_id: shop.data.id,
      user_id: created.data.user.id,
      role: "shop_admin",
      is_active: true,
    });
    if (membership.error) {
      await adminClient.from("shops").delete().eq("id", shop.data.id);
      await adminClient.auth.admin.deleteUser(created.data.user.id);
      return json({ error: membership.error.message }, 500);
    }

    await adminClient.from("audit_logs").insert({
      shop_id: shop.data.id,
      actor_user_id: callerId,
      action: "shop.created",
      target_type: "shop",
      target_id: shop.data.id,
      details: { admin_email: email },
    });
    return json({ shop: shop.data, admin_user_id: created.data.user.id });
  }

  if (action === "create_worker") {
    const shopId = typeof body.shop_id === "string" ? body.shop_id : "";
    if (!shopId) return json({ error: "shop_id is required" }, 400);

    if (!isOwner) {
      const { data: membership } = await adminClient
        .from("shop_memberships")
        .select("role, is_active")
        .eq("shop_id", shopId)
        .eq("user_id", callerId)
        .maybeSingle();
      if (!membership || membership.role !== "shop_admin" || !membership.is_active) {
        return json({ error: "Shop administrator access required" }, 403);
      }
    }

    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const password = body.password;
    const name = typeof body.display_name === "string" ? body.display_name.trim().slice(0, 120) : "";
    if (!validEmail(email) || !validPassword(password)) {
      return json({ error: "Provide a valid email and password of at least 8 characters" }, 400);
    }

    const requested = body.permissions && typeof body.permissions === "object"
      ? body.permissions as Record<string, unknown>
      : {};
    const permissions = Object.fromEntries(
      Object.keys(defaultPermissions).map((key) => [
        key,
        typeof requested[key] === "boolean" ? requested[key] : defaultPermissions[key as keyof typeof defaultPermissions],
      ]),
    );

    const created = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: name },
    });
    if (created.error || !created.data.user) {
      return json({ error: created.error?.message ?? "Could not create worker account" }, 400);
    }

    const inserted = await adminClient.from("shop_memberships").insert({
      shop_id: shopId,
      user_id: created.data.user.id,
      role: "worker",
      is_active: true,
      permissions,
    });
    if (inserted.error) {
      await adminClient.auth.admin.deleteUser(created.data.user.id);
      return json({ error: inserted.error.message }, 500);
    }

    await adminClient.from("audit_logs").insert({
      shop_id: shopId,
      actor_user_id: callerId,
      action: "worker.created",
      target_type: "shop_membership",
      target_id: created.data.user.id,
      details: { email, permissions },
    });
    return json({ user_id: created.data.user.id, email, permissions });
  }

  if (action === "update_worker_permissions") {
    const shopId = typeof body.shop_id === "string" ? body.shop_id : "";
    const userId = typeof body.user_id === "string" ? body.user_id : "";
    if (!shopId || !userId) return json({ error: "shop_id and user_id are required" }, 400);

    if (!isOwner) {
      const { data: membership } = await adminClient
        .from("shop_memberships")
        .select("role, is_active")
        .eq("shop_id", shopId)
        .eq("user_id", callerId)
        .maybeSingle();
      if (!membership || membership.role !== "shop_admin" || !membership.is_active) {
        return json({ error: "Shop administrator access required" }, 403);
      }
    }

    const { data: target } = await adminClient
      .from("shop_memberships")
      .select("role")
      .eq("shop_id", shopId)
      .eq("user_id", userId)
      .maybeSingle();
    if (!target || target.role !== "worker") {
      return json({ error: "Worker membership not found" }, 404);
    }

    const requested = body.permissions && typeof body.permissions === "object"
      ? body.permissions as Record<string, unknown>
      : {};
    const permissions = Object.fromEntries(
      Object.keys(defaultPermissions).map((key) => [
        key,
        typeof requested[key] === "boolean" ? requested[key] : false,
      ]),
    );
    const updated = await adminClient.from("shop_memberships")
      .update({ permissions })
      .eq("shop_id", shopId)
      .eq("user_id", userId);
    if (updated.error) return json({ error: updated.error.message }, 500);

    await adminClient.from("audit_logs").insert({
      shop_id: shopId,
      actor_user_id: callerId,
      action: "worker.permissions_updated",
      target_type: "shop_membership",
      target_id: userId,
      details: { permissions },
    });
    return json({ user_id: userId, permissions });
  }

  return json({ error: "Unknown action" }, 400);
});
