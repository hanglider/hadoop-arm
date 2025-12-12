#!/usr/bin/env python3
import sys

def email_to_domain(s: str) -> str | None:
    s = s.strip()
    if not s:
        return None
    # ожидаем email в строке
    if "@" not in s:
        return None
    _, dom = s.rsplit("@", 1)
    dom = dom.strip().lower()
    if not dom:
        return None
    # иногда прилетает "name <email@dom>" — на всякий случай почистим
    if ">" in dom:
        dom = dom.split(">", 1)[0].strip()
    return dom or None

for line in sys.stdin:
    dom = email_to_domain(line)
    if dom:
        sys.stdout.write(f"{dom}\t1\n")