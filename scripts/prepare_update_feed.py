#!/usr/bin/env python3
"""Send pre-1.2.0 clients to a manual download after the update-key rotation."""
import argparse
import os
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
parser.add_argument('tag')
args = parser.parse_args()
namespace = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', namespace)
feed = args.output / 'appcast.xml'
tree = ET.parse(feed)
for item in tree.findall('channel/item'):
    info = item.find(f'{{{namespace}}}informationalUpdate')
    if info is None:
        info = ET.SubElement(item, f'{{{namespace}}}informationalUpdate')
    below = info.find(f'{{{namespace}}}belowVersion')
    if below is None:
        below = ET.SubElement(info, f'{{{namespace}}}belowVersion')
    below.text = '9'
    link = item.find('link')
    if link is None:
        link = ET.SubElement(item, 'link')
    link.text = f'https://github.com/elixirevo/wewi/releases/tag/{args.tag}'
tree.write(feed, encoding='utf-8', xml_declaration=True)
root = Path(__file__).resolve().parent.parent
signer = next(p for p in sorted((root / '.build/artifacts').rglob('sign_update'))
              if 'old_dsa_scripts' not in p.parts and p.is_file())
subprocess.run([str(signer), '--account', os.environ.get('SPARKLE_KEY_ACCOUNT', 'wewi'), str(feed)], check=True)
