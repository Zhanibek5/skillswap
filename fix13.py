import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_button = """
                                  ),
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

content = content.replace("                                  ),\n                                ),\n                              ),", new_button)

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

