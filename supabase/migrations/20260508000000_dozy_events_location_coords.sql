-- 일정 위치 자동완성 + 지도 임베드 — 자동완성에서 고른 좌표 저장.
-- 사용자가 텍스트만 치고 안 고른 경우엔 NULL → 클라이언트에서 지도 미표시.
ALTER TABLE dozy_events
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
