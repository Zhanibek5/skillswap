import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if "                                          builder: (_) => const SavedVideosList(" in line and "),                                                                                                                      )," in lines[i+1]:
        new_lines.append("                                          builder: (_) => const SavedVideosList(),\n")
        continue
    if "),                                                                                                                      )," in line and "                                          builder: (_) => const SavedVideosList(" in lines[i-1]:
        continue

    new_lines.append(line)

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

