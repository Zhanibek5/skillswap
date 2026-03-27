import os
import glob

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = content.replace('Color(0xFF1D2226)', 'Color(0xFF1E1E1E)')

    if content != new_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f'Fixed {filepath}')

for ext in ['**/*.dart']:
    for filepath in glob.glob('lib/' + ext, recursive=True):
        process_file(filepath)
