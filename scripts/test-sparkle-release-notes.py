#!/usr/bin/env python3
"""Exercise the release workflow's Sparkle update description against sample release notes."""
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/macos-notarized-release.yml'
START = 'python3 -I - "$RELEASE_NOTES_PATH"'


def description_script():
    lines = WORKFLOW.read_text().splitlines()
    start = next(index for index, line in enumerate(lines) if START in line) + 1
    end = next(index for index in range(start, len(lines)) if lines[index].strip() == 'PY')
    return textwrap.dedent('\n'.join(lines[start:end]))


SCRIPT = description_script()


def describe(notes):
    with tempfile.TemporaryDirectory() as directory:
        notes_path = Path(directory) / 'release-notes.md'
        description_path = Path(directory) / 'update.md'
        notes_path.write_text(notes)
        subprocess.run([sys.executable, '-I', '-', str(notes_path), str(description_path)],
            input=SCRIPT, text=True, check=True)
        return description_path.read_text() if description_path.exists() else None


class SparkleReleaseNotesTests(unittest.TestCase):
    def test_removes_trailing_installation(self):
        notes = textwrap.dedent('''\
            ## New

            - Crate can now update itself.

            ## Installation

            Download the signed and notarized ZIP from this release, extract it, and move the app to Applications.
            ''')
        self.assertEqual(describe(notes), '## New\n\n- Crate can now update itself.\n')

    def test_keeps_sections_after_installation(self):
        notes = textwrap.dedent('''\
            ## New

            - Presets can cap memory.

            ## installation

            Download the ZIP.

            ### Requirements

            macOS 15 or later.

            ## Fixes

            - Speeds are correct.
            ''')
        self.assertEqual(describe(notes),
            '## New\n\n- Presets can cap memory.\n\n## Fixes\n\n- Speeds are correct.\n')

    def test_keeps_notes_without_installation(self):
        self.assertEqual(describe('## Fixes\n\n- Installation no longer stalls.\n'),
            '## Fixes\n\n- Installation no longer stalls.\n')

    def test_omits_description_with_only_installation(self):
        self.assertIsNone(describe('## Installation\n\nDownload the ZIP.\n'))


if __name__ == '__main__':
    unittest.main()
