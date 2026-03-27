import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for index, line in enumerate(lines):
    new_lines.append(line)
    
    if "import 'edit_profile_page.dart';" in line:
        new_lines.append("import 'saved_videos_list.dart';\n")
        continue

    if "                                  label: const Text(\"View Feedback\")," in line:
        # we append the new button correctly after this block
        pass
        
    if "/* MAGIC_MARKER */" in line:
        pass

