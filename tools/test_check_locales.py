#!/usr/bin/env python3
"""Negative contracts for the localization checker; no Godot/editor mutation."""
import struct
import unittest
from check_locales import LOCALES, font_codepoints, parse_po, placeholders, pseudo_expand, validate_catalogs


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


if __name__ == '__main__':
    unittest.main()
