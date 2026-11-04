"""Static checks for the planning documents. Python standard library only.

Run: python3 tools/check_docs.py
Exit code is non-zero when any check fails. This is a document check,
not the game gate (tools/gate.sh), and it does not run the game.
"""
from pathlib import Path
import hashlib, json, re, sys, urllib.parse

root = Path(__file__).resolve().parents[1]
files = sorted(root.glob("*.md")) + sorted((root / "docs").rglob("*.md"))
errors, local_links, anchors, json_count = [], 0, 0, 0

# Original feedback files are kept byte-for-byte; revisions go in the response doc.
PRESERVED = {
    "docs/reviews/CLAUDE_FEEDBACK_20261104.md": "c030a95b05ecf667cf63657d3695667c216ac17d51edac85503afa207b92fdd2",
    "docs/reviews/CLAUDE_FEEDBACK_20261104_R2.md": "2deb03f1daf8d51a72fdb2fe49c6e6f2d3c5d1450a2cdbc72a366ee7739a69dc",
}


def read_document(path):
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        errors.append(f"missing required document: {path.name}")
    except (OSError, UnicodeError) as exc:
        errors.append(f"cannot read document: {path.name} ({type(exc).__name__})")
    return ""


def heading_ids(text):
    found, seen = set(), {}
    for heading in re.findall(r"^#{1,6} +(.+)$", text, re.M):
        base = re.sub(r"[^\w\s-]", "", heading.replace("`", "").lower())
        base = re.sub(r"\s", "-", base)
        n = seen.get(base, 0)
        seen[base] = n + 1
        found.add(base if n == 0 else f"{base}-{n}")
    return found

assert heading_ids("# 현재 상태\n# 현재 상태\n") == {"현재-상태", "현재-상태-1"}

for path in files:
    text = read_document(path)
    if text.count("```") % 2:
        errors.append(f"{path.relative_to(root)}: unclosed fence")
    for target in re.findall(r"(?<!!)\[[^\]]+\]\(([^\s)]+)(?:\s+\"[^\"]*\")?\)", text):
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
            continue
        decoded = urllib.parse.unquote(target.strip("<>"))
        rel, _, fragment = decoded.partition("#")
        dest = (path.parent / rel).resolve() if rel else path
        local_links += 1
        if not dest.is_file():
            errors.append(f"{path.relative_to(root)} -> missing {target}")
        elif fragment and dest.suffix == ".md":
            anchors += 1
            if fragment not in heading_ids(read_document(dest)):
                errors.append(f"{path.relative_to(root)} -> missing anchor {target}")
    for block in re.findall(r"```json\s*\n(.*?)\n```", text, re.S):
        json_count += 1
        try:
            json.loads(block, parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))
        except ValueError as exc:
            errors.append(f"{path.relative_to(root)}: invalid JSON {exc}")

curriculum = read_document(root / "docs/CURRICULUM.md")
cards = re.findall(r"^#### (M\d{2})[^\n]*\n(.*?)(?=^#### M\d{2}|^### |^## |\Z)", curriculum, re.M | re.S)
if [mid for mid, _ in cards] != [f"M{i:02}" for i in range(1, 25)]:
    errors.append("mission IDs must be M01..M24")
graph = {}
for mid, body in cards:
    prereq = re.search(r"\*\*선수 ID:\*\*([^\n]*)", body)
    graph[mid] = re.findall(r"M\d{2}", prereq[1].split("**유형:")[0].split("**스토리:")[0]) if prereq else []
    for field in ["선수 ID", "유형", "스토리", "첫 학습", "재사용 기술", "도구", "플레이 행동", "상태 기반 성공", "오답 복구", "전이 질문"]:
        if f"**{field}:" not in body:
            errors.append(f"{mid}: missing {field}")
active, seen = set(), set()
def visit(mid):
    if mid in active:
        errors.append("prerequisite cycle at " + mid)
        return
    if mid in seen:
        return
    active.add(mid)
    for prior in graph.get(mid, []):
        if prior not in graph:
            errors.append("unknown prerequisite " + prior)
        else:
            visit(prior)
    active.remove(mid)
    seen.add(mid)
for mid in graph:
    visit(mid)

pacing = read_document(root / "docs/PACING_AND_STORY.md")
budgets = []
for table in re.findall(r"(?:^\|.*\n)+", pacing, re.M):
    if not any(k in table.splitlines()[0] for k in ["빠른 첫 플레이", "충분히 탐색"]):
        continue
    values, total = [], None
    for row in table.splitlines()[2:]:
        cols = [x.strip() for x in row.strip("|").split("|")]
        match = re.search(r"(\d+)분", cols[-1])
        if not match:
            continue
        value = int(match[1])
        if "합계" in cols[0]:
            total = value
        else:
            values.append(value)
            formula = re.search(r"(\d+)개.*×.*?(\d+)분", cols[0])
            if formula and int(formula[1]) * int(formula[2]) != value:
                errors.append("pacing multiplication mismatch: " + row)
    if total is None or sum(values) != total:
        errors.append("pacing sum mismatch")
    budgets.append(total)
if budgets != [480, 240]:
    errors.append("pacing budgets must remain 480 + 240 minutes")

preserved_ok = {}
for rel, expected in PRESERVED.items():
    try:
        preserved_ok[rel] = hashlib.sha256((root / rel).read_bytes()).hexdigest() == expected
    except FileNotFoundError:
        preserved_ok[rel] = False
        errors.append("missing required document: " + rel)
        continue
    except OSError as exc:
        preserved_ok[rel] = False
        errors.append(f"cannot read document: {rel} ({type(exc).__name__})")
        continue
    if not preserved_ok[rel]:
        errors.append("preserved feedback changed: " + rel)

result = {
    "markdown_files": len(files), "local_links": local_links, "anchors": anchors,
    "json_blocks": json_count, "main_missions": len(cards), "pacing_minutes": budgets,
    "preserved_unchanged": preserved_ok,
    "game_project_exists": (root / "godot/project.godot").exists(),
    "errors": errors,
}
print(json.dumps(result, ensure_ascii=True, indent=2))
sys.exit(bool(errors))
