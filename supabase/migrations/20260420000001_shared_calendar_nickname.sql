-- shared_calendar_members에 nickname 컬럼 추가
ALTER TABLE public.shared_calendar_members
ADD COLUMN IF NOT EXISTS nickname text;

-- 본인 row의 nickname만 수정 가능하도록 UPDATE RLS 정책 추가
CREATE POLICY "members can update own nickname"
ON public.shared_calendar_members
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
