"""The one-time transfer copies data without executing Lua or overwriting files."""
from pathlib import Path
import importlib.util
import tempfile
import unittest
import sys

ROOT = Path(__file__).resolve().parents[1]


class TransferTests(unittest.TestCase):
    def setUp(self):
        tool = ROOT / 'tools/transfer_saved_data.py'
        self.assertTrue(tool.is_file(), 'Saved-data transfer tool missing')
        spec = importlib.util.spec_from_file_location('transfer_saved_data', tool)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.source = Path(self.directory.name) / 'input.lua'
        self.destination = Path(self.directory.name) / 'Gatherly.lua'

    def test_preserves_payload_strings_comments_schema_and_input_bytes(self):
        payload = ''' = {\r\n ["version"] = 1, ["nodes"] = {}, ["routes"] = {},\r\n ["settings"] = { ["text"] = "a } and \\\"quote\\\"", ["other"] = [=[{text}]=] }, -- }\r\n}\r\n'''
        original = ('-- saved data\r\nSourceDB' + payload).encode('utf-8')
        self.source.write_bytes(original)
        self.module.transfer(self.source, self.destination)
        self.assertEqual(self.source.read_bytes(), original)
        self.assertEqual(self.destination.read_bytes(), ('GatherlyDB' + payload).encode('utf-8'))

    def test_accepts_bom_and_long_comments_without_parsing_them_as_tables(self):
        self.source.write_bytes(b'\xef\xbb\xbf--[=[ } ignored ]=]\nSourceDB = { ["nodes"] = {} }\n')
        self.module.transfer(self.source, self.destination)
        self.assertEqual(self.destination.read_text(), 'GatherlyDB = { ["nodes"] = {} }\n')

    def test_refuses_existing_destination(self):
        self.source.write_text('SourceDB = {}')
        self.destination.write_text('keep this')
        with self.assertRaises(FileExistsError):
            self.module.transfer(self.source, self.destination)
        self.assertEqual(self.destination.read_text(), 'keep this')

    def test_refuses_same_file(self):
        self.source.write_text('SourceDB = {}')
        with self.assertRaises(ValueError):
            self.module.transfer(self.source, self.source)
        self.assertEqual(self.source.read_text(), 'SourceDB = {}')

    def test_rejects_invalid_or_multiple_roots_without_output(self):
        for content in ['return {}', 'SourceDB = 1', 'SourceDB = {', 'SourceDB = {}\nOtherDB = {}', 'SourceDB = { "unterminated }', 'SourceDB = { --[[ unfinished']:
            with self.subTest(content=content):
                self.source.write_text(content)
                with self.assertRaises(ValueError):
                    self.module.transfer(self.source, self.destination)
                self.assertFalse(self.destination.exists())

    def test_never_executes_lua_payload(self):
        self.source.write_text('SourceDB = { ["text"] = (function() error("must not execute") end)() }')
        self.module.transfer(self.source, self.destination)
        self.assertIn('error("must not execute")', self.destination.read_text())

    def test_transferred_trusted_fixture_opens_with_existing_store_schema(self):
        try:
            from lupa.lua51 import LuaRuntime
        except ImportError:
            sys.path.insert(0, str(ROOT / '.test-deps'))
            from lupa.lua51 import LuaRuntime
        self.source.write_text('SourceDB = { version=1, nodes={}, routes={}, nextNode=2, nextRoute=3, settings={arrival=25,panel={preset="large"}} }')
        self.module.transfer(self.source, self.destination)
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(self.destination.read_text())  # Trusted test fixture only.
        lua.execute('A={}; assert(loadfile(...))("Gatherly",A)', str(ROOT / 'Store.lua'))
        saved, writable = lua.eval('A.Store.Open')(lua.globals().GatherlyDB)
        self.assertTrue(writable)
        self.assertEqual(saved.nextNode, 2)
        self.assertEqual(saved.nextRoute, 3)
        self.assertEqual(saved.settings.arrival, 25)
        self.assertEqual(saved.settings.panel.preset, 'large')


if __name__ == '__main__':
    unittest.main()
