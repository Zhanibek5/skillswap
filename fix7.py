import sys
import re

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'const SavedVideosList\(\n\)[ ]+\)', 'const SavedVideosList()', content)
content = re.sub(r'const SavedVideosList\(\n\)[ \t]*\)', 'const SavedVideosList()', content)

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
