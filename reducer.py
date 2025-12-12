#!/usr/bin/env python3
import sys
import heapq

TOP_N = 10

def push_top(heap, count: int, domain: str):
    item = (count, domain)
    if len(heap) < TOP_N:
        heapq.heappush(heap, item)
    else:
        if item > heap[0]:
            heapq.heapreplace(heap, item)

current_domain = None
current_sum = 0
top = []  # min-heap of (count, domain)

for raw in sys.stdin:
    raw = raw.strip()
    if not raw:
        continue

    parts = raw.split("\t")
    if len(parts) != 2:
        continue

    domain = parts[0].strip()
    try:
        cnt = int(parts[1])
    except ValueError:
        continue

    if current_domain is None:
        current_domain = domain
        current_sum = cnt
        continue

    if domain == current_domain:
        current_sum += cnt
    else:
        push_top(top, current_sum, current_domain)
        current_domain = domain
        current_sum = cnt

# flush last
if current_domain is not None:
    push_top(top, current_sum, current_domain)

# output sorted desc: count \t domain
for count, domain in sorted(top, reverse=True):
    sys.stdout.write(f"{count}\t{domain}\n")