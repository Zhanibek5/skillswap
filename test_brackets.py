import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if "                    )," in line and "                  )," in lines[i+1] and "                ]," in lines[i+2] and "              );" in lines[i+3]:
        # we need to close the Column inside the children of Column 
        # Wait, let's see why it's missing.
        continue

    new_lines.append(line)

