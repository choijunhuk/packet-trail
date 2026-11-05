#!/usr/bin/env python3
"""Merge authored UI translations; exact repeated labels reuse existing translations."""
import json
import hashlib
import re
from check_locales import ROOT

REVIEWED_SOURCE = {'ko': '6e2edc8e649af41aebad7f7ddd297961b55a5d0e9bdb9a65e7cc0ad7a812bc18', 'en': '69eca61a796975c9870ea5959898d14b311a02cb63eb72317d52ea7211002213'}


def build():
    directory = ROOT / 'godot/locales'
    for locale in ('ko', 'en'):
        path = ROOT / f'godot/assets/ui/strings_{locale}.json'
        if hashlib.sha256(path.read_bytes()).hexdigest() != REVIEWED_SOURCE[locale]:
            raise ValueError(f'{locale}: UI source revision needs translation review')
    ko = json.loads((ROOT / 'godot/assets/ui/strings_ko.json').read_text(encoding='utf-8'))
    en = json.loads((ROOT / 'godot/assets/ui/strings_en.json').read_text(encoding='utf-8'))
    if set(ko) != set(en):
        raise ValueError('UI source key sets differ')
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
