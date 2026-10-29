// send-push — 공유 캘린더 파트너 APNs 푸시 (#95)
//
// 호출: dozy_events 트리거(notify_shared_event_push)가 pg_net 으로 { event_id } 를 POST.
//       x-dozy-push-secret 헤더가 PUSH_WEBHOOK_SECRET 과 같아야 한다 (JWT 검증은 끔 — config.toml).
// 동작: 일정 · 작성자 닉네임 조회 → 작성자를 뺀 멤버의 토큰(공유 알림 켬) → APNs HTTP/2 발송
//       410 Unregistered · 400 BadDeviceToken 이면 토큰 행 삭제.
// 시크릿 (supabase secrets set): APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY(.p8 내용), APNS_BUNDLE_ID, PUSH_WEBHOOK_SECRET
//
// 문구는 앱의 SharedEventNotificationText 와 같은 loc-key — 기기 언어로 iOS 가 번역한다. 바꾸면 양쪽을 함께 바꾼다.

import { createClient } from "jsr:@supabase/supabase-js@2.49.4";

const SENDER_KEY = "%@님이 '%@' 일정을 공유했습니다";
const PARTNER_KEY = "파트너님이 '%@' 일정을 공유했습니다";

const env = (name: string): string => {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing env ${name}`);
  return value;
};

// ---------------------------------------------------------------------------
// APNs provider token (ES256 JWT) — 최대 1시간 유효, 20분마다 새로 만든다
// ---------------------------------------------------------------------------

let cachedJWT: { token: string; issuedAt: number } | null = null;

const base64url = (bytes: Uint8Array): string =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

const importKey = async (pem: string): Promise<CryptoKey> => {
  // 시크릿에 줄바꿈이 실제 개행 또는 "\n" 문자로 들어와도 읽는다
  const body = pem.replace(/\\n/g, "").replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
};

const providerToken = async (): Promise<string> => {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT && now - cachedJWT.issuedAt < 20 * 60) return cachedJWT.token;
  const enc = new TextEncoder();
  const header = base64url(enc.encode(JSON.stringify({ alg: "ES256", kid: env("APNS_KEY_ID") })));
  const claims = base64url(enc.encode(JSON.stringify({ iss: env("APNS_TEAM_ID"), iat: now })));
  const key = await importKey(env("APNS_PRIVATE_KEY"));
  // WebCrypto ECDSA 서명은 r||s (64바이트) — JWT ES256 형식 그대로
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(`${header}.${claims}`)),
  );
  const token = `${header}.${claims}.${base64url(signature)}`;
  cachedJWT = { token, issuedAt: now };
  return token;
};

// ---------------------------------------------------------------------------

type TokenRow = { token: string; environment: "sandbox" | "production" };

const sendOne = async (row: TokenRow, payload: unknown, threadID: string): Promise<{ ok: boolean; gone: boolean; reason?: string }> => {
  const host = row.environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const res = await fetch(`https://${host}/3/device/${row.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken()}`,
      "apns-topic": env("APNS_BUNDLE_ID"),
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": String(Math.floor(Date.now() / 1000) + 24 * 3600),
      "apns-collapse-id": threadID.slice(0, 64),
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (res.ok) return { ok: true, gone: false };
  const reason = (await res.json().catch(() => ({})))?.reason as string | undefined;
  const gone = res.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered";
  return { ok: false, gone, reason: `${res.status} ${reason ?? ""}`.trim() };
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  if (req.headers.get("x-dozy-push-secret") !== env("PUSH_WEBHOOK_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }

  const { event_id: eventID } = await req.json().catch(() => ({}));
  if (typeof eventID !== "string" || !eventID) return new Response("bad request", { status: 400 });

  const db = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false },
  });

  const { data: event, error: eventError } = await db
    .from("dozy_events")
    .select("id, user_id, title, start_date, shared_calendar_id, external_source")
    .eq("id", eventID)
    .maybeSingle();
  if (eventError) return new Response(eventError.message, { status: 500 });
  if (!event || !event.shared_calendar_id || event.external_source) {
    return Response.json({ sent: 0, skipped: "not a shared native event" });
  }

  const { data: members, error: membersError } = await db
    .from("shared_calendar_members")
    .select("user_id, nickname")
    .eq("shared_calendar_id", event.shared_calendar_id);
  if (membersError) return new Response(membersError.message, { status: 500 });

  const sender = members?.find((m) => m.user_id === event.user_id)?.nickname?.trim() || null;
  const recipients = (members ?? []).map((m) => m.user_id).filter((id) => id !== event.user_id);
  if (recipients.length === 0) return Response.json({ sent: 0, skipped: "no recipients" });

  const { data: tokens, error: tokensError } = await db
    .from("push_tokens")
    .select("token, environment")
    .in("user_id", recipients)
    .eq("shared_enabled", true);
  if (tokensError) return new Response(tokensError.message, { status: 500 });

  const payload = {
    aps: {
      alert: sender
        ? { "loc-key": SENDER_KEY, "loc-args": [sender, event.title] }
        : { "loc-key": PARTNER_KEY, "loc-args": [event.title] },
      sound: "default",
      "thread-id": event.shared_calendar_id,
    },
    dozy: {
      type: "shared_event",
      event_id: event.id,
      calendar_id: event.shared_calendar_id,
      title: event.title,
      sender,
      start: event.start_date,
    },
  };

  let sent = 0;
  const gone: string[] = [];
  const failures: string[] = [];
  for (const row of (tokens ?? []) as TokenRow[]) {
    const result = await sendOne(row, payload, `${event.id}`);
    if (result.ok) sent++;
    else if (result.gone) gone.push(row.token);
    else failures.push(result.reason ?? "unknown");
  }
  if (gone.length > 0) {
    await db.from("push_tokens").delete().in("token", gone);
    console.log(`send-push: removed ${gone.length} invalid token(s)`);
  }
  if (failures.length > 0) console.warn(`send-push: ${failures.length} failure(s): ${failures.join(", ")}`);

  return Response.json({ sent, removed: gone.length, failed: failures.length });
});
