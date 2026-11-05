#!/usr/bin/env python3
"""Merge authored UI translations; exact repeated labels reuse existing translations."""
import json
import re
from check_locales import ROOT, read_ui_sources


def build():
    directory = ROOT / 'godot/locales'
    sources = read_ui_sources()
    ko, en = sources['ko'], sources['en']
    memory = {values[0]: values[2:] for values in json.loads((directory / 'common.json').read_text(encoding='utf-8')).values()}
    drafts = {}
    for path in sorted(directory.glob('ui*-drafts.json')):
        for key, values in json.loads(path.read_text(encoding='utf-8')).items():
            if key in drafts:
                raise ValueError(f'duplicate UI translation: {key}')
            drafts[key] = values
    stale = set(drafts) - set(ko)
    if stale:
        raise ValueError(f'stale UI translation keys: {sorted(stale)}')
    for key, values in drafts.items():
        memory[ko[key]] = values
    rows, missing = {}, []
    for key, original in ko.items():
        values = drafts.get(key, memory.get(original))
        if values is None and not re.search('[가-힣]', original):
            # These source entries are canonical names, JSON examples or pure interpolation.
            values = [en[key]] * 4
        if values is None or len(values) != 4 or any(not value.strip() for value in values):
            missing.append(key)
        else:
            rows[key] = [original, en[key], *values]
    if missing:
        raise ValueError(f'UI translations still required: {missing}')
    (directory / 'ui.source.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'ok': True, 'ui_keys': len(rows), 'extra_languages': 4}))


if __name__ == '__main__':
    build()
