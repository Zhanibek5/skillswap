import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    # around line 560 we have the bad commented out code
    if "//         MaterialPageRoute(" in line:
        continue
    if "//           builder: (_) => const SavedVideosPage()," in line:
        continue
    if "//         )," in line:
        continue
    if "//       );" in line:
        continue
    if "//     }," in line:
        continue
    if "//     child: Text(\"Video\"))" in line:
        continue
    
    # fix the broken SavedVideoList line
    if "const SavedVideosList()" in line and "()                                                                                                                      )," in lines[i+1]:
        # we can just fix this by replacing the line 
        new_lines.append("                                          builder: (_) => const SavedVideosList(),\n")
        continue
    
    if "()                                                                                                                      )," in line and "const SavedVideosList(" in lines[i-1]:
        continue

    new_lines.append(line)

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

