#!/usr/bin/env python3
"""Strict repository PO, interpolation, canonical-token and font integrity checks."""
from __future__ import annotations
import argparse
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ('ko', 'en', 'ja', 'zh_Hans', 'es', 'de')
CAMPAIGN_SOURCES = {
    'legacy_intruder': ('godot/data/campaign/locales/{}.json', ''),
    'intruder': ('godot/data/campaign/locales/intruder_v2.{}.json', 'IN2_'),
    'defender': ('godot/data/campaign/locales/defender_v1.{}.json', 'DF1_'),
    'tracker': ('godot/data/campaign/locales/tracker_v1.{}.json', 'TR1_'),
}
KEY = re.compile(r'^[A-Z][A-Z0-9_]*$')
NAMED = re.compile(r'(?<!\{)\{(?:[A-Za-z_][A-Za-z_0-9]*|\d+)\}(?!\})')
PRINTF = re.compile(r'%(?:\([A-Za-z_][A-Za-z_0-9]*\))?[-+0 #]*\d*(?:\.\d+)?[sdifxXocv]')
CANONICAL = re.compile(
    r'`[^`\n]+`|https?://[A-Za-z0-9./_?=&%:+#~-]+'
    r'|[a-z][a-z0-9_-]*@[a-z0-9.-]+(?: / |\n)[A-Za-z0-9_-]+'
    r'|(?<![A-Za-z0-9_/])~?/(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+'
    r'|(?<![A-Za-z0-9_])(?:[a-z0-9-]+\.)+packet\.test(?:/[A-Za-z0-9./_-]+)?'
    r'|\b(?:\d{1,3}\.){3}\d{1,3}\b'
    r'|(?<![A-Za-z0-9_])(?:inspect|retain|lumen|relay|transit|archive)-[a-z0-9-]+'
    r'|(?<![A-Za-z0-9_])(?!(?:M|S|R|P)\d{2}(?!\d))(?:ECHO-\d+|[A-Z]+\d+)(?![A-Za-z0-9_])'
    r'|(?<![A-Za-z0-9_])(?:guest|analyst|auditor) / [A-Za-z0-9-]+'
    r'|(?<![A-Za-z0-9_])(?:maint|route\.txt)(?![A-Za-z0-9_])'
    r'|(?<![A-Za-z0-9_])0x[0-9A-Fa-f]+(?![A-Za-z0-9_])'
)


def parse_po(text: str) -> tuple[dict[str, str], str]:
    """Read our singular, context-free gettext contract; reject ambiguous/fuzzy input."""
    entries: dict[str, str] = {}
    current: dict[str, str] = {}
    active = ''
    header = ''

    def finish() -> None:
        nonlocal header, current, active
        if not current:
            return
        if set(current) != {'msgid', 'msgstr'}:
            raise ValueError('entry requires exactly msgid and msgstr')
        key, value = current['msgid'], current['msgstr']
        if key == '':
            if header:
                raise ValueError('duplicate PO header')
            header = value
        else:
            if not KEY.fullmatch(key):
                raise ValueError(f'not a stable message key: {key!r}')
            if key in entries:
                raise ValueError(f'duplicate key: {key}')
            if not value.strip():
                raise ValueError(f'empty translation: {key}')
            entries[key] = value
        current, active = {}, ''

    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line:
            finish()
            continue
        if line.startswith('#'):
            if line.startswith('#~') or (line.startswith('#,') and 'fuzzy' in line):
                raise ValueError(f'line {number}: obsolete/fuzzy translation')
            continue
        match = re.fullmatch(r'(msgid|msgstr)\s+(".*")', line)
        if match:
            field, literal = match.groups()
            if field == 'msgid' and 'msgstr' in current:
                finish()
            if field in current or (field == 'msgstr' and 'msgid' not in current):
                raise ValueError(f'line {number}: duplicate or unordered field')
            active = field
        elif line.startswith('"') and active:
            literal = line
        else:
            raise ValueError(f'line {number}: unsupported PO syntax')
        try:
            decoded = ast.literal_eval(literal)
        except (ValueError, SyntaxError) as error:
            raise ValueError(f'line {number}: invalid string') from error
        if not isinstance(decoded, str) or '\x00' in decoded:
            raise ValueError(f'line {number}: invalid string value')
        current[active] = current.get(active, '') + decoded
    finish()
    if not header or 'charset=UTF-8' not in header:
        raise ValueError('missing UTF-8 header')
    return entries, header


def placeholders(text: str) -> Counter[str]:
    return Counter(NAMED.findall(text) + PRINTF.findall(text.replace('%%', '')))


def tokens(text: str) -> Counter[str]:
    return Counter(value.rstrip('.,;:!?') for value in CANONICAL.findall(text))


def pseudo_expand(text: str, ratio: float = 0.4) -> str:
    # Keep placeholders and canonical tokens intact so the fixture also tests formatting.
    return '⟦' + text + ' ' + '·' * max(1, round(len(text) * ratio)) + '⟧'


def read_operational_prose(root: Path = ROOT) -> dict[str, list[str]]:
    prose = json.loads((root / 'godot/locales/operational-prose.json').read_text(encoding='utf-8'))
    if not isinstance(prose, dict) or len(prose) != 16 or any(not isinstance(key, str) or not isinstance(values, list)
            or len(values) != 5 or any(not isinstance(value, str) or not value.strip() for value in values)
            for key, values in prose.items()):
        raise ValueError('legacy educational prose requires 16 ko/ja/zh_Hans/es/de entries')
    return prose


def translate_prose(text: str, locale: str, prose: dict[str, list[str]]) -> str:
    if locale == 'en':
        return text
    index = ('ko', 'ja', 'zh_Hans', 'es', 'de').index(locale)
    for original, values in prose.items():
        text = text.replace(original, values[index])
    return text


def validate_educational_prose(catalogs: dict[str, dict[str, str]], prose: dict[str, list[str]]) -> list[str]:
    return [f'{locale}/{key}: untranslated educational paragraph'
            for locale, catalog in catalogs.items() if locale != 'en'
            for key, text in catalog.items() if any(original in text for original in prose)]


def reviewed_catalog(root: Path, relative: str, review: dict) -> dict[str, str]:
    path = root / relative
    if not isinstance(review, dict) or review.get('path') != relative:
        raise ValueError(f'{relative}: source is not registered for review')
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != review.get('sha256'):
        raise ValueError(f'{relative}: source revision needs translation review')
    source = json.loads(raw.decode('utf-8'))
    if not isinstance(source, dict) or not source or any(not KEY.fullmatch(key) or not isinstance(value, str)
            or not value.strip() for key, value in source.items()):
        raise ValueError(f'{relative}: invalid stable-key source catalog')
    return source


def read_source_reviews(root: Path) -> dict:
    reviews = json.loads((root / 'godot/locales/source-revisions.json').read_text(encoding='utf-8'))
    if not isinstance(reviews, dict) or set(reviews) != {'campaigns', 'ui'}:
        raise ValueError('invalid locale source review manifest')
    if not isinstance(reviews['campaigns'], dict) or not isinstance(reviews['ui'], dict):
        raise ValueError('invalid locale source review groups')
    if set(reviews['ui']) != {'ko', 'en'} or any(not isinstance(group, dict) or set(group) != {'ko', 'en'}
            for group in reviews['campaigns'].values()):
        raise ValueError('source review requires explicit KO/EN revisions')
    return reviews


def read_campaign_sources(root: Path = ROOT) -> dict[str, dict[str, dict[str, str]]]:
    reviews = read_source_reviews(root)['campaigns']
    if not isinstance(reviews, dict) or set(reviews) - set(CAMPAIGN_SOURCES):
        raise ValueError('unregistered campaign source pack')
    result = {}
    for pack, (pattern, prefix) in CAMPAIGN_SOURCES.items():
        if pack not in reviews and not any((root / pattern.format(locale)).exists() for locale in ('ko', 'en')):
            continue
        group = {locale: reviewed_catalog(root, pattern.format(locale), reviews.get(pack, {}).get(locale))
                 for locale in ('ko', 'en')}
        if set(group['ko']) != set(group['en']):
            raise ValueError(f'{pack}: KO/EN source keys differ')
        if prefix and any(not key.startswith(prefix) for key in group['en']):
            raise ValueError(f'{pack}: source keys require {prefix} namespace')
        result[pack] = group
    return result


def read_ui_sources(root: Path = ROOT) -> dict[str, dict[str, str]]:
    reviews = read_source_reviews(root)['ui']
    result = {locale: reviewed_catalog(root, f'godot/assets/ui/strings_{locale}.json', reviews.get(locale))
              for locale in ('ko', 'en')}
    if set(result['ko']) != set(result['en']):
        raise ValueError('UI source keys differ')
    return result


def validate_catalogs(catalogs: dict[str, dict[str, str]], required: set[str] | None = None) -> list[str]:
    errors: list[str] = []
    baseline = catalogs.get('en', {})
    expected = set(baseline)
    if not expected:
        errors.append('en: empty catalog')
    for locale in LOCALES:
        catalog = catalogs.get(locale, {})
        missing, extra = expected - set(catalog), set(catalog) - expected
        if missing or extra:
            errors.append(f'{locale}: missing={sorted(missing)} extra={sorted(extra)}')
        for key in expected & set(catalog):
            value = catalog[key]
            if not value.strip():
                errors.append(f'{locale}/{key}: empty translation')
            if placeholders(value) != placeholders(baseline[key]):
                errors.append(f'{locale}/{key}: placeholder mismatch')
            if tokens(value) != tokens(baseline[key]):
                errors.append(f'{locale}/{key}: canonical token mismatch')
            if locale in ('ja', 'zh_Hans', 'es', 'de') and re.search('[가-힣]', value):
                errors.append(f'{locale}/{key}: untranslated Korean text')
            if locale in ('ja', 'zh_Hans', 'es', 'de') and value == baseline[key] and len(value) >= 40 and ' ' in value:
                errors.append(f'{locale}/{key}: untranslated English passage')
    if required and required - expected:
        errors.append(f'content keys absent: {sorted(required - expected)}')
    return errors


def required_content_keys(root: Path) -> set[str]:
    result: set[str] = set()
    presentation = {'title', 'name', 'goal_text', 'sender', 'subject', 'body', 'hints', 'tutorial',
                    'explain', 'principle', 'abstraction', 'limit', 'text', 'label', 'description'}
    def visit(value: object, field: str = '') -> None:
        if field == 'program':
            # Keep virtual instruction labels and opcodes canonical.
            return
        if isinstance(value, dict):
            for key, item in value.items():
                visit(item, key)
        elif isinstance(value, list):
            for item in value:
                visit(item, field)
        elif isinstance(value, str) and (field in presentation or field.endswith('_key')) and KEY.fullmatch(value):
            result.add(value)
    for relative in ['godot/data/campaign/campaign.json', 'godot/data/campaign/legacy_v1.json',
                     'godot/data/campaign/packs/intruder_v2.json', 'godot/data/campaign/packs/defender_v1.json',
                     'godot/data/campaign/packs/tracker_v1.json']:
        campaign = root / relative
        if campaign.exists():
            visit(json.loads(campaign.read_text(encoding='utf-8')))
    return result


def check_fonts(root: Path) -> list[str]:
    errors: list[str] = []
    directory = root / 'godot/assets/fonts'
    for suffix in ('JP', 'SC', 'Mono'):
        try:
            source = json.loads((directory / f'SOURCE-{suffix}.json').read_text(encoding='utf-8'))
            font = directory / f'NotoSans{suffix}.ttf'
            license_file = directory / source['license_file']
            for path, expected in [(font, source['sha256']), (license_file, source['license_sha256'])]:
                if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                    errors.append(f'{path.name}: SHA256 mismatch')
            if font.stat().st_size < 1_000_000 or font.read_bytes()[:4] not in (b'\x00\x01\x00\x00', b'OTTO'):
                errors.append(f'{font.name}: not a full OpenType/TrueType font')
            if 'SIL OPEN FONT LICENSE Version 1.1' not in license_file.read_text(encoding='utf-8'):
                errors.append(f'{license_file.name}: OFL missing')
            if not re.fullmatch(r'[a-f0-9]{40}', source['upstream_commit']) or source['upstream_commit'] not in source['download']:
                errors.append(f'{suffix}: unpinned source')
            if not source['download'].startswith('https://raw.githubusercontent.com/google/fonts/'):
                errors.append(f'{suffix}: unofficial font source')
        except (OSError, ValueError, KeyError, TypeError) as error:
            errors.append(f'{suffix}: font provenance: {error}')
    if not (directory / 'NotoSansKR.ttf').is_file():
        errors.append('existing KR primary font missing')
    return errors


def font_codepoints(data: bytes) -> set[int]:
    """Read Unicode cmap 4/12 from the shipped TTFs without a font dependency."""
    tables = struct.unpack_from('>H', data, 4)[0]
    cmap = None
    for index in range(tables):
        tag, _, offset, _ = struct.unpack_from('>4sIII', data, 12 + index * 16)
        if tag == b'cmap':
            cmap = offset
    if cmap is None:
        raise ValueError('font has no cmap')
    points: set[int] = set()
    count = struct.unpack_from('>H', data, cmap + 2)[0]
    for index in range(count):
        platform, encoding, offset = struct.unpack_from('>HHI', data, cmap + 4 + index * 8)
        if platform != 0 and not (platform == 3 and encoding in (1, 10)):
            continue
        start = cmap + offset
        format_id = struct.unpack_from('>H', data, start)[0]
        if format_id == 12:
            groups = struct.unpack_from('>I', data, start + 12)[0]
            for group in range(groups):
                first, last, glyph = struct.unpack_from('>III', data, start + 16 + group * 12)
                if last > 0x10FFFF or first > last:
                    raise ValueError('invalid Unicode cmap group')
                points.update(range(first + (glyph == 0), last + 1))
        elif format_id == 4:
            segments = struct.unpack_from('>H', data, start + 6)[0] // 2
            ends = start + 14
            starts = ends + 2 * segments + 2
            deltas = starts + 2 * segments
            ranges = deltas + 2 * segments
            for segment in range(segments):
                last = struct.unpack_from('>H', data, ends + 2 * segment)[0]
                first = struct.unpack_from('>H', data, starts + 2 * segment)[0]
                delta = struct.unpack_from('>h', data, deltas + 2 * segment)[0]
                distance = struct.unpack_from('>H', data, ranges + 2 * segment)[0]
                for point in range(first, min(last, 0xFFFE) + 1):
                    glyph = (point + delta) & 0xFFFF
                    if distance:
                        address = ranges + 2 * segment + distance + 2 * (point - first)
                        glyph = struct.unpack_from('>H', data, address)[0]
                        glyph = ((glyph + delta) & 0xFFFF) if glyph else 0
                    if glyph:
                        points.add(point)
    if not points:
        raise ValueError('font has no supported Unicode cmap')
    return points


def check_glyphs(root: Path, catalogs: dict[str, dict[str, str]]) -> list[str]:
    try:
        coverage: set[int] = set()
        for suffix in ('KR', 'JP', 'SC', 'Mono'):
            coverage.update(font_codepoints((root / f'godot/assets/fonts/NotoSans{suffix}.ttf').read_bytes()))
        missing = sorted({ord(char) for catalog in catalogs.values() for text in catalog.values()
                          for char in text if not char.isspace() and ord(char) not in coverage})
        return [f'font chain lacks Unicode glyphs: {[f"U+{point:04X}" for point in missing]}'] if missing else []
    except (OSError, ValueError, struct.error) as error:
        return [f'font cmap: {error}']


def check(root: Path = ROOT) -> dict:
    catalogs: dict[str, dict[str, str]] = {}
    errors: list[str] = []
    for locale in LOCALES:
        try:
            catalog, header = parse_po((root / f'godot/locales/{locale}.po').read_text(encoding='utf-8'))
            if f'Language: {locale}\n' not in header:
                errors.append(f'{locale}: incorrect Language header')
            catalogs[locale] = catalog
        except (OSError, UnicodeError, ValueError) as error:
            errors.append(f'{locale}: {error}')
    prose = read_operational_prose(root)
    errors += validate_catalogs(catalogs, required_content_keys(root))
    errors += validate_educational_prose(catalogs, prose)
    sources = read_campaign_sources(root)
    sources['UI'] = read_ui_sources(root)
    merged = {'ko': {}, 'en': {}}
    for group, translations in sources.items():
        for locale in ('ko', 'en'):
            for key, value in translations[locale].items():
                if key in merged[locale] and merged[locale][key] != value:
                    errors.append(f'{group}/{locale}/{key}: conflicting shared source key')
                merged[locale][key] = value
                if catalogs.get(locale, {}).get(key) != translate_prose(value, locale, prose):
                    errors.append(f'{locale}/{key}: {group} source changed; rebuild translations')
    errors += check_fonts(root)
    errors += check_glyphs(root, catalogs)
    try:
        fixtures = json.loads((root / 'godot/locales/pseudo-layout.json').read_text(encoding='utf-8'))
        if fixtures['expansion_ratio'] < .3 or fixtures['expansion_ratio'] > .5:
            errors.append('pseudo expansion must be 30–50%')
        if fixtures['viewports'] != [[1280, 720], [1600, 900]] or fixtures['font_scales'] != [1.0, 1.6]:
            errors.append('pseudo layout viewport/font-scale contract missing')
        for key, expanded in fixtures['strings'].items():
            if key not in catalogs.get('en', {}) or expanded != pseudo_expand(catalogs['en'][key], fixtures['expansion_ratio']):
                errors.append(f'{key}: stale pseudo expansion')
        if len(fixtures['strings']) < 5:
            errors.append('insufficient pseudo layout samples')
    except (OSError, ValueError, KeyError, TypeError) as error:
        errors.append(f'pseudo layout data: {error}')
    return {'ok': not errors, 'locales': len(catalogs), 'messages_per_locale': len(catalogs.get('en', {})),
            'checks': ['PO syntax', 'six-locale parity', 'nonempty', 'placeholders', 'canonical tokens', 'localized educational paragraphs', 'campaign/UI keys/source sync', 'font hashes/licenses', 'all catalog glyphs', 'pseudo expansion data'],
            'errors': errors}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        report = check(args.root)
    except (OSError, ValueError, TypeError) as error:
        report = {'ok': False, 'errors': [str(error)]}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
