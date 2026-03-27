import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if "                      ]," in line and "                    )," in lines[i+1] and "                  )," in lines[i+2]:
        # we need to close children for the Container before this
        new_lines.append("                            ],\n")
        new_lines.append("                          ),\n")
        new_lines.append("                        ),\n")

    new_lines.append(line)

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

