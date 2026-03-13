import re

file_path = r'c:\Users\User\Desktop\skillswap\lib\MainPage\chat\chats_list_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

parts = text.split('<<<<<<< HEAD')
if len(parts) == 2:
    start = parts[0]
    rest = parts[1]
    parts2 = rest.split('>>>>>>> 0697032 (feat: Add technical support chat page)')
    if len(parts2) == 2:
        end = parts2[1]
        
        replacement = '''      backgroundColor: Colors.white,
      body: Column(
        children: [
          /// TITLE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, top: 60, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "SkillSwap",
                  style: GoogleFonts.roboto(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E88E5),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupportPage()),
                    );
                  },
                  icon: const Icon(Icons.support_agent_outlined),
                  color: Colors.grey[700],
                  tooltip: 'support'.tr(),
                ),
              ],
            ),
          ),

          /// SEARCH
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value.toLowerCase();
                  });
                },
                style: const TextStyle(color: Colors.grey),
                decoration: const InputDecoration(
                  hintText: "Search by name or skill",
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ),
          ),'''
        
        # In the original, the part matching end starts immediately after >>>>>>>... so we also need to take care of the \n                ),...
        # Let's clean up the trailing part from the end string
        # Wait, looking at the previous log, >>>>>>> line was inside the Column.
        # The remainder end starts with:
        # \n                ),\n              ),\n            ),\n          ),\n\n          /// CHAT LIST
        # We need to remove the closed parentheses that belong to the replaced part.
        
        end_clean = re.sub(r'^\s*\),\s*\),\s*\),\s*\),\s*', '\n\n', end)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(start + replacement + end_clean)
        print("Replaced!")
    else:
        print("Could not find >>>>>>> part")
else:
    print("Could not find <<<<<<< HEAD part")
