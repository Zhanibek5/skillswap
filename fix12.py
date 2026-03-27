import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_button = """
                                  ),
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SavedVideosList(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.video_library),
                                    label: const Text("Saved Video in History"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF1E88E5),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),"""

# We just missed the exact match. Let's make sure it's the right block.
content = content.replace("                                  ),\n                                ),\n                              ],", "                                  ),\n                                )," + new_button + "\n                              ],")

content = content.replace("import 'edit_profile_page.dart';", "import 'edit_profile_page.dart';\nimport 'saved_videos_list.dart';")

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

