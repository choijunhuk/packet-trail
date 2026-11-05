#!/usr/bin/env python3
"""Validate frozen legacy and new pack translations against separately reviewed source revisions."""
import json
from pathlib import Path
from check_locales import ROOT, read_campaign_sources


def build(root: Path = ROOT) -> dict:
    groups = read_campaign_sources(root)
    directory = root / 'godot/locales'
    for pack, source in groups.items():
        names = ['narrative.source.json', 'campaign.source.json'] if pack == 'legacy_intruder' else [f'pack-{pack}.source.json']
        rows = {}
        for name in names:
            catalog = json.loads((directory / name).read_text(encoding='utf-8'))
            if not isinstance(catalog, dict) or set(rows) & set(catalog):
                raise ValueError(f'{pack}: duplicate or invalid translation catalog')
            rows.update(catalog)
        if set(rows) != set(source['en']):
            raise ValueError(f'{pack}: missing or stale translation keys')
        for key, values in rows.items():
            if (not isinstance(values, list) or len(values) != 6
                    or any(not isinstance(value, str) or not value.strip() for value in values)
                    or values[:2] != [source['ko'][key], source['en'][key]]):
                raise ValueError(f'{pack}/{key}: translated source revision differs')
    report = {'ok': True, 'campaign_keys': sum(len(group['en']) for group in groups.values()),
              'packs': list(groups), 'extra_languages': 4}
    print(json.dumps(report))
    return report


if __name__ == '__main__':
    build()
