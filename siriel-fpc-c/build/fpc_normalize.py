#!/usr/bin/env python3
# fpc_normalize.py — read raw FPC compiler output from stdin, write compact
import re, sys, json

LINE_RE = re.compile(
    r'^(?P<file>[\w./\-\\ ]+\.(pas|inc|o|c|ppu|mac|a|dylib|so))\((?P<line>\d+)(?:,(?P<col>\d+))?\)\s+'
    r'(?P<kind>Error|Fatal|Warning|Hint)(?:\s+\[(?P<code>\w+)\])?\s*[: ]?(?P<msg>.*)$'
)

# Collapse huge runtime backtraces / heap dumps to a single marker.
BACKTRACE_RE = re.compile(r'(?:Stack overflow|Heap dump|Bad pointer|Bad class|'
                          r'Blocker|EAccessViolation|ESystemError|Segmentation '
                          r'fault|EXC_BAD_ACCESS|runtime error|backtrace)',
                          re.IGNORECASE)

errors = []
warnings = []
seen = set()

for raw in sys.stdin:
    line = raw.rstrip('\n')
    m = LINE_RE.match(line.strip())
    if not m:
        continue
    file = m.group('file').strip()
    line_no = int(m.group('line'))
    col = int(m.group('col')) if m.group('col') else 0
    kind = m.group('kind')
    msg = m.group('msg').strip()
    key = (file, line_no, kind, msg)
    if key in seen:
        continue
    seen.add(key)
    entry = {'file': file, 'line': line_no, 'column': col, 'message': msg}
    if kind in ('Error', 'Fatal'):
        errors.append(entry)
    else:
        warnings.append(entry)

# Collapse runtime backtrace lines that slipped through (no file:line header).
rt = []
for e in errors:
    if BACKTRACE_RE.search(e['message']):
        rt.append(e)
if rt:
    errors = [e for e in errors if not BACKTRACE_RE.search(e['message'])]
    errors.append({'file': '(runtime)', 'line': 0, 'column': 0,
                   'message': 'Runtime crash detected, see raw log if needed'})

first = errors[0] if errors else None
summary = (f"Parsed {len(errors)} error(s), {len(warnings)} warning(s)."
           + (f" First error at {first['file']}:{first['line']}" if first else ""))

out = {
    'total_errors': len(errors),
    'total_warnings': len(warnings),
    'first_error': first,
    'all_errors': errors,
}
with open('errors.json', 'w') as f:
    json.dump(out, f, indent=2)
print(summary)
