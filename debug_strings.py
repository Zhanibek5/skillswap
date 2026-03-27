import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "const SavedVideosList" in line:
        print(repr(line))
        try:
            print(repr(lines[i+1]))
        except:
            pass

