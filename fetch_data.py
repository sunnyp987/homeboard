#!/usr/bin/env python3
"""Fetch the household calendar and write data.json for the dashboard.

The page cannot fetch Google's iCal feed directly (no CORS headers), so this
runs on the Pi instead and leaves a same-origin JSON file beside index.html.

Reads config.json — which is gitignored, because the secret iCal URL is a
credential: anyone holding it can read the whole calendar.
"""

import json
import sys
import urllib.request
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import icalendar
import recurring_ical_events

APP_DIR = Path(__file__).resolve().parent
CONFIG = APP_DIR / "config.json"
OUT = APP_DIR / "data.json"


def load_config():
    if not CONFIG.exists():
        sys.exit(f"No config.json at {CONFIG} — copy config.example.json and fill it in.")
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
    if not cfg.get("ical_url", "").startswith("http"):
        sys.exit("config.json needs an 'ical_url' — the calendar's secret iCal address.")
    return cfg


def fmt_time(dt, tz):
    """2:00p, 11:30a — matches the dashboard's existing time style."""
    local = dt.astimezone(tz)
    hour = local.hour % 12 or 12
    suffix = "a" if local.hour < 12 else "p"
    return f"{hour}:{local.minute:02d}{suffix}"


def main():
    cfg = load_config()
    tz = ZoneInfo(cfg.get("timezone", "America/Chicago"))

    with urllib.request.urlopen(cfg["ical_url"], timeout=30) as resp:
        cal = icalendar.Calendar.from_ical(resp.read())

    # Cover the visible month grid plus padding weeks on either side, so
    # trailing/leading days of adjacent months get their dots too.
    today = datetime.now(tz).date()
    start = today.replace(day=1) - timedelta(days=7)
    end = (today.replace(day=1) + timedelta(days=62)).replace(day=1) + timedelta(days=7)

    # recurring_ical_events expands RRULEs — weekly trash day, monthly
    # deep clean, etc. Hand-rolled ICS parsing silently drops all of those.
    events = recurring_ical_events.of(cal).between(start, end)

    days = {}
    for ev in events:
        raw = ev["DTSTART"].dt
        if isinstance(raw, datetime):
            key = raw.astimezone(tz).date().isoformat()
            entry = {"time": fmt_time(raw, tz), "summary": str(ev.get("SUMMARY", "Busy"))}
        else:  # all-day events carry a plain date
            key = raw.isoformat()
            entry = {"time": None, "summary": str(ev.get("SUMMARY", "Busy"))}
        days.setdefault(key, []).append(entry)

    for entries in days.values():
        # All-day first, then chronological.
        entries.sort(key=lambda e: (e["time"] is not None, e["time"] or ""))

    OUT.write_text(
        json.dumps(
            {"generated": datetime.now(tz).isoformat(timespec="seconds"), "days": days},
            indent=1,
        ),
        encoding="utf-8",
    )
    print(f"wrote {OUT} — {sum(len(v) for v in days.values())} events across {len(days)} days")


if __name__ == "__main__":
    main()
