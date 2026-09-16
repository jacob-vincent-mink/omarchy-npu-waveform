import importlib.util
import unittest
import tempfile
from pathlib import Path

spec = importlib.util.spec_from_file_location('reader', Path(__file__).parents[1] / 'power-reader/reader.py')
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)

class PowerReaderTests(unittest.TestCase):
    def test_initial_sample(self):
        self.assertIsNone(reader.watts(None, (10, 5_000_000, 10_000_000)))

    def test_wraparound(self):
        self.assertEqual(reader.watts((10, (1 << 32) - 16384, 1 << 32), (12, 16384, 1 << 32)), 1)

    def test_pmt_register_decode(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / 'telem').write_bytes(bytes(0x670) + (123456).to_bytes(4, 'little'))
            self.assertEqual(reader.npu_counter(path), (123456, 1 << 32))
            (path / 'telem').write_bytes(bytes(0x672))
            with self.assertRaises(ValueError):
                reader.npu_counter(path)

    def test_discontinuity(self):
        before = (10, 9_000_000, 10_000_000)
        for after in [(10, 9_000_000, 10_000_000), (20, 1_000_000, 10_000_000), (11, 1_000_000, 20_000_000)]:
            self.assertIsNone(reader.watts(before, after))

if __name__ == '__main__':
    unittest.main()
