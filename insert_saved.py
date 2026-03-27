import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if "                                )," in line and "                              )," in lines[i+1] and "                            ]," in lines[i+2] and "                          )," in lines[i+3] and "                        )," in lines[i+4] and "                        SizedBox(" in lines[i+5]:
        new_lines.append("                                const SizedBox(height: 15),\n")
        new_lines.append("                                SizedBox(\n")
        new_lines.append("                                  width: double.infinity,\n")
        new_lines.append("                                  child: ElevatedButton.icon(\n")
        new_lines.append("                                    onPressed: () {\n")
        new_lines.append("                                      Navigator.push(\n")
        new_lines.append("                                        context,\n")
        new_lines.append("                                        MaterialPageRoute(\n")
        new_lines.append("                                          builder: (_) => const SavedVideosList(),\n")
        new_lines.append("                                        ),\n")
        new_lines.append("                                      );\n")
        new_lines.append("                                    },\n")
        new_lines.append("                                    icon: const Icon(Icons.video_library),\n")
        new_lines.append("                                    label: const Text(\"Saved Video in History\"),\n")
        new_lines.append("                                    style: ElevatedButton.styleFrom(\n")
        new_lines.append("                                      backgroundColor: Color(0xFF1E88E5),\n")
        new_lines.append("                                      foregroundColor: Colors.white,\n")
        new_lines.append("                                      padding: const EdgeInsets.symmetric(\n")
        new_lines.append("                                          vertical: 14),\n")
        new_lines.append("                                      shape: RoundedRectangleBorder(\n")
        new_lines.append("                                        borderRadius: BorderRadius.circular(12),\n")
        new_lines.append("                                      ),\n")
        new_lines.append("                                    ),\n")
        new_lines.append("                                  ),\n")
        new_lines.append("                                ),\n")

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

