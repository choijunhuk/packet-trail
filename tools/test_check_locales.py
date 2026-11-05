#!/usr/bin/env python3
"""Negative contracts for the localization checker; no Godot/editor mutation."""
import struct
import contextlib
import hashlib
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from build_locales import build
from import_campaign_locales import build as validate_campaign_import
from check_locales import (LOCALES, ROOT, font_codepoints, parse_po, placeholders, pseudo_expand,
                          read_operational_prose, tokens, translate_prose, validate_catalogs,
                          validate_educational_prose, read_campaign_sources, reviewed_catalog)
from check_locales import required_content_keys


class LocaleChecks(unittest.TestCase):
    def catalogs(self):
        return {locale: {'TEST_MESSAGE': f'{locale} {{record}} /archive/evidence.txt 10.0.0.2'} for locale in LOCALES}

    def test_valid_six_locale_parity(self):
        self.assertEqual(validate_catalogs(self.catalogs()), [])

    def test_missing_key(self):
        catalogs = self.catalogs()
        catalogs['ja'].clear()
        self.assertTrue(any('missing' in error for error in validate_catalogs(catalogs)))

    def test_required_campaign_key(self):
        self.assertTrue(any('content keys absent' in error for error in validate_catalogs(self.catalogs(), {'M01_TITLE'})))

    def test_duplicate_placeholder_is_detected(self):
        catalogs = self.catalogs()
        catalogs['de']['TEST_MESSAGE'] += ' {record}'
        self.assertTrue(any('placeholder' in error for error in validate_catalogs(catalogs)))

    def test_indexed_and_hex_placeholders(self):
        self.assertEqual(placeholders('{0}: %02X / %.2f / %%'), {'{0}': 1, '%02X': 1, '%.2f': 1})

    def test_canonical_token_mutation(self):
        catalogs = self.catalogs()
        catalogs['es']['TEST_MESSAGE'] = catalogs['es']['TEST_MESSAGE'].replace('/archive/', '/archivo/')
        self.assertTrue(any('canonical token' in error for error in validate_catalogs(catalogs)))

    def test_domain_password_record_and_ip_are_stable(self):
        original = 'guest / guest maint https://mirror.packet.test/cache/47 10.0.0.2 ECHO-21 N47 inspect-m02'
        for old, new in [('mirror.packet.test', 'other.packet.test'), ('inspect-m02', 'translated-m02'),
                         ('ECHO-21', 'ECHO-22'), ('10.0.0.2', '10.0.0.3'), ('maint', 'maintenance')]:
            catalogs = {locale: {'TEST_MESSAGE': f'{locale} {original}'} for locale in LOCALES}
            catalogs['ja']['TEST_MESSAGE'] = catalogs['ja']['TEST_MESSAGE'].replace(old, new)
            with self.subTest(token=old):
                self.assertTrue(any('canonical token' in error for error in validate_catalogs(catalogs)))

    def test_role_account_and_fictional_secret_are_stable(self):
        original = 'logreader@relay-desk.packet.test / patrol-ember-desk'
        for old, new in [('logreader', 'reader'), ('patrol-ember-desk', 'translated-secret')]:
            catalogs = {locale: {'TEST_MESSAGE': f'{locale} {original}'} for locale in LOCALES}
            catalogs['de']['TEST_MESSAGE'] = catalogs['de']['TEST_MESSAGE'].replace(old, new)
            with self.subTest(token=old):
                self.assertTrue(any('canonical token' in error for error in validate_catalogs(catalogs)))

    def test_home_relative_path_is_not_absolute(self):
        catalogs = {locale: {'TEST_MESSAGE': f'{locale} ~/archive'} for locale in LOCALES}
        catalogs['es']['TEST_MESSAGE'] = 'es /archive'
        self.assertTrue(any('canonical token' in error for error in validate_catalogs(catalogs)))

    def test_multiline_work_account_is_canonical(self):
        account = 'operator@d01.defender.packet.test\nnight-duty'
        catalogs = {locale: {'TEST_MESSAGE': locale + ' ' + account} for locale in LOCALES}
        catalogs['ja']['TEST_MESSAGE'] = 'ja ' + account.replace('night-duty', 'translated-password')
        self.assertTrue(any('canonical token' in error for error in validate_catalogs(catalogs)))

    def test_untranslated_korean(self):
        catalogs = self.catalogs()
        catalogs['zh_Hans']['TEST_MESSAGE'] += ' 한국어 원문'
        self.assertTrue(any('untranslated Korean' in error for error in validate_catalogs(catalogs)))

    def test_english_fallback_is_not_translation(self):
        catalogs = self.catalogs()
        catalogs['en']['TEST_MESSAGE'] = 'This English paragraph has not been translated into the selected language.'
        catalogs['ja']['TEST_MESSAGE'] = catalogs['en']['TEST_MESSAGE']
        self.assertTrue(any('untranslated English' in error for error in validate_catalogs(catalogs)))

    def test_font_unicode_cmap(self):
        # One Unicode format-12 group, including glyph zero which must stay missing.
        table = struct.pack('>HHHHI', 0, 1, 3, 10, 12)
        table += struct.pack('>HHIII', 12, 0, 28, 0, 1) + struct.pack('>III', 0x3040, 0x3042, 0)
        font = b'\x00\x01\x00\x00' + struct.pack('>HHHH', 1, 0, 0, 0)
        font += struct.pack('>4sIII', b'cmap', 0, 28, len(table)) + table
        self.assertEqual(font_codepoints(font), {0x3041, 0x3042})

    def test_broken_font_rejected(self):
        with self.assertRaises((ValueError, struct.error)):
            font_codepoints(b'not a font')

    def test_po_multiline_unicode(self):
        messages, header = parse_po('msgid ""\nmsgstr "Language: ja\\nContent-Type: text/plain; charset=UTF-8\\n"\n\nmsgid "TEST_MESSAGE"\nmsgstr "記録\\n"\n"続き"\n')
        self.assertEqual(messages, {'TEST_MESSAGE': '記録\n続き'})
        self.assertIn('Language: ja', header)

    def test_malformed_po_rejected(self):
        for text in ['msgid "A"\nmsgstr "unterminated', 'msgstr "A"', 'msgid "A"\nmsgid "B"', '#, fuzzy\nmsgid "A"\nmsgstr "B"']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_po(text)

    def test_duplicate_po_key_rejected(self):
        with self.assertRaisesRegex(ValueError, 'duplicate key'):
            parse_po('msgid ""\nmsgstr "Content-Type: text/plain; charset=UTF-8\\n"\n\nmsgid "KEY_A"\nmsgstr "One"\n\nmsgid "KEY_A"\nmsgstr "Two"')

    def test_pseudo_preserves_format_tokens(self):
        original = 'Record {record} at /archive/evidence.txt'
        expanded = pseudo_expand(original)
        self.assertGreaterEqual(len(expanded), len(original) * 1.3)
        self.assertEqual(placeholders(expanded), placeholders(original))
        self.assertIn('/archive/evidence.txt', expanded)

    def test_ko_educational_paragraph_is_translated(self):
        prose = read_operational_prose()
        original = next(iter(prose))
        self.assertTrue(validate_educational_prose({'ko': {'TEST_MESSAGE': original}}, prose))
        rendered = translate_prose(original, 'ko', prose)
        self.assertEqual(rendered, prose[original][0])
        self.assertFalse(validate_educational_prose({'ko': {'TEST_MESSAGE': rendered}}, prose))
        self.assertEqual(translate_prose(original, 'en', prose), original)

    def test_educational_translation_preserves_machine_material(self):
        prose = read_operational_prose()
        original = next(iter(prose))
        machine = 'logreader@relay-desk.packet.test / patrol-ember-desk\nGET /receipts/C731\n'
        source = machine + original
        rendered = translate_prose(source, 'ko', prose)
        self.assertTrue(rendered.startswith(machine))
        self.assertEqual(tokens(rendered), tokens(source))
        self.assertEqual(translate_prose(machine, 'ko', prose), machine)
        fragment = original[:20]
        self.assertEqual(translate_prose(fragment, 'ko', prose), fragment)

    def test_all_known_ko_educational_paragraphs_are_absent_from_po(self):
        prose = read_operational_prose()
        catalog, _ = parse_po((ROOT / 'godot/locales/ko.po').read_text(encoding='utf-8'))
        self.assertFalse(validate_educational_prose({'ko': catalog}, prose))

    def test_missing_ko_prose_column_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            locales = root / 'godot/locales'
            locales.mkdir(parents=True)
            prose = read_operational_prose()
            prose[next(iter(prose))] = prose[next(iter(prose))][1:]
            (locales / 'operational-prose.json').write_text(json.dumps(prose), encoding='utf-8')
            with self.assertRaises(ValueError):
                read_operational_prose(root)

    def test_shared_source_keys_match_exactly_or_fail_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            locales = root / 'godot/locales'
            locales.mkdir(parents=True)
            for name in ('common.json', 'operational-prose.json'):
                shutil.copyfile(ROOT / 'godot/locales' / name, locales / name)
            row = {'TEST_SHARED_KEY': ['공유', 'Shared', '共有', '共享', 'Compartido', 'Gemeinsam']}
            for name in ('one.source.json', 'two.source.json'):
                (locales / name).write_text(json.dumps(row), encoding='utf-8')
            with contextlib.redirect_stdout(io.StringIO()):
                build(root)
            before = (locales / 'ko.po').read_bytes()
            messages, _ = parse_po(before.decode())
            self.assertEqual(messages['TEST_SHARED_KEY'], '공유')
            row['TEST_SHARED_KEY'][-1] = 'Different meaning'
            (locales / 'two.source.json').write_text(json.dumps(row), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'conflicting production key'):
                build(root)
            self.assertEqual((locales / 'ko.po').read_bytes(), before)

    def test_pack_source_revisions_are_independent_and_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            locales = root / 'godot/locales'
            locales.mkdir(parents=True)
            manifest = {'campaigns': {}, 'ui': {'ko': {}, 'en': {}}}
            for pack, stem, prefix in [('legacy_intruder', '', 'M01_'), ('intruder', 'intruder_v2.', 'IN2_')]:
                manifest['campaigns'][pack] = {}
                for language in ('ko', 'en'):
                    relative = f'godot/data/campaign/locales/{stem}{language}.json'
                    path = root / relative
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(json.dumps({prefix + 'TITLE': language + ' title'}), encoding='utf-8')
                    manifest['campaigns'][pack][language] = {'path': relative, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            review_path = locales / 'source-revisions.json'
            review_path.write_text(json.dumps(manifest), encoding='utf-8')
            self.assertEqual(set(read_campaign_sources(root)), {'legacy_intruder', 'intruder'})
            changed = root / 'godot/data/campaign/locales/intruder_v2.ko.json'
            changed.write_text('{"IN2_TITLE":"changed after review"}', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'needs translation review'):
                read_campaign_sources(root)
            legacy = manifest['campaigns']['legacy_intruder']['ko']
            self.assertEqual(reviewed_catalog(root, legacy['path'], legacy), {'M01_TITLE': 'ko title'})
            with self.assertRaisesRegex(ValueError, 'not registered'):
                reviewed_catalog(root, legacy['path'], {'path': '../outside.json', 'sha256': legacy['sha256']})

    def test_pack_source_namespace_and_language_parity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'godot/locales').mkdir(parents=True)
            manifest = {'campaigns': {'defender': {}}, 'ui': {'ko': {}, 'en': {}}}
            for language in ('ko', 'en'):
                relative = f'godot/data/campaign/locales/defender_v1.{language}.json'
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('{"IN2_WRONG_PACK":"wrong namespace"}', encoding='utf-8')
                manifest['campaigns']['defender'][language] = {'path': relative, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            (root / 'godot/locales/source-revisions.json').write_text(json.dumps(manifest), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'DF1_ namespace'):
                read_campaign_sources(root)
            relative = 'godot/data/campaign/locales/defender_v1.en.json'
            path = root / relative
            path.write_text('{"DF1_TITLE":"different key set"}', encoding='utf-8')
            manifest['campaigns']['defender']['en']['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            (root / 'godot/locales/source-revisions.json').write_text(json.dumps(manifest), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'KO/EN source keys differ'):
                read_campaign_sources(root)

    def test_pack_translation_import_needs_no_content_generator(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            locales = root / 'godot/locales'
            locales.mkdir(parents=True)
            row = {'IN2_TITLE': ['새 사건', 'New case', '新しい事件', '新事件', 'Caso nuevo', 'Neuer Fall']}
            manifest = {'campaigns': {'intruder': {}}, 'ui': {'ko': {}, 'en': {}}}
            for index, language in enumerate(('ko', 'en')):
                relative = f'godot/data/campaign/locales/intruder_v2.{language}.json'
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps({'IN2_TITLE': row['IN2_TITLE'][index]}), encoding='utf-8')
                manifest['campaigns']['intruder'][language] = {'path': relative, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            (locales / 'source-revisions.json').write_text(json.dumps(manifest), encoding='utf-8')
            target = locales / 'pack-intruder.source.json'
            target.write_text(json.dumps(row), encoding='utf-8')
            before = target.read_bytes()
            with contextlib.redirect_stdout(io.StringIO()):
                report = validate_campaign_import(root)
            self.assertEqual(report['campaign_keys'], 1)
            self.assertEqual(target.read_bytes(), before)
            row['IN2_TITLE'][2] = ''
            target.write_text(json.dumps(row), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'translated source revision differs'):
                validate_campaign_import(root)

    def test_program_labels_are_canonical_not_translation_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'godot/data/campaign/packs/intruder_v2.json'
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps({'challenges': {'vm': {'kind': 'branch_vm', 'name': 'IN2_VM_NAME',
                'program': {'functions': {'main': [{'label': 'ENTRY', 'op': 'HALT'}]}}}}}), encoding='utf-8')
            self.assertEqual(required_content_keys(root), {'IN2_VM_NAME'})


if __name__ == '__main__':
    unittest.main()
