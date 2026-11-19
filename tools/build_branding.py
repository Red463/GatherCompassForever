"""Prepare the supplied Gatherly artwork for WoW."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('prepare_supplied_assets.py')), run_name='__main__')
runpy.run_path(str(Path(__file__).with_name('build_marker_textures.py')), run_name='__main__')
