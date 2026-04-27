#!/usr/bin/env python3
"""
한국 공휴일 데이터를 공공데이터포털 특일정보 API 에서 가져와
holidays.json 으로 직렬화한다.

사용:
    export HOLIDAY_API_KEY='발급받은_decoding_키'
    python3 scripts/fetch_holidays.py > scripts/holidays.json
    cp scripts/holidays.json "Dozy AI/Resources/holidays.json"

매년 정부가 차년도 공휴일을 새로 발표하면 다시 돌리면 끝.
임시공휴일 추가 시에도 동일 — Supabase Storage 의 holidays.json 도 함께 갈아끼우면
배포 없이 모든 사용자에게 hot-update 됨.

API 키 발급:
    https://www.data.go.kr/iim/api/selectAPIAcountView.do
    "특일 정보" 검색 후 활용신청 — 일반 인증키(Decoding) 사용.
"""

import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import date

ENDPOINT = "https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo"


def fetch_year(service_key: str, year: int) -> list[dict]:
    params = {
        "serviceKey": service_key,
        "solYear": str(year),
        "_type": "json",
        "numOfRows": "100",
    }
    qs = urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
    url = f"{ENDPOINT}?{qs}"
    with urllib.request.urlopen(url, timeout=10) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    body = data.get("response", {}).get("body", {})
    items_raw = body.get("items", {})
    if not items_raw:
        return []
    items = items_raw.get("item", [])
    if isinstance(items, dict):
        items = [items]
    return items


def to_date_str(locdate) -> str:
    s = str(locdate)
    return f"{s[0:4]}-{s[4:6]}-{s[6:8]}"


def main():
    service_key = os.environ.get("HOLIDAY_API_KEY", "").strip()
    if not service_key:
        sys.exit(
            "❌ HOLIDAY_API_KEY 환경변수가 설정되지 않았습니다.\n"
            "   export HOLIDAY_API_KEY='발급받은_decoding_키' 후 재실행."
        )

    # 정부가 매년 차년도 공휴일을 단계적으로 발표 — 빈 해는 자동 skip.
    years = list(range(2020, 2031))
    holidays = []
    fetched_years = []
    for y in years:
        print(f"fetching {y}...", file=sys.stderr)
        items = fetch_year(service_key, y)
        if not items:
            print("  (no data — skip)", file=sys.stderr)
            continue
        fetched_years.append(y)
        for it in items:
            if it.get("isHoliday") != "Y":
                continue
            name = it.get("dateName", "")
            holidays.append(
                {
                    "date": to_date_str(it["locdate"]),
                    "name": name,
                    "isSubstitute": "대체공휴일" in name,
                }
            )
    if not fetched_years:
        sys.exit("❌ 어떤 해에서도 데이터를 받지 못함 — API 키 확인 필요")
    holidays.sort(key=lambda h: h["date"])

    out = {
        "version": date.today().isoformat(),
        "source": "data.go.kr / 한국천문연구원 특일정보",
        "range": {
            "from": f"{fetched_years[0]}-01-01",
            "to": f"{fetched_years[-1]}-12-31",
        },
        "holidays": holidays,
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
