import re

file_path = r'c:\Users\User\Desktop\skillswap\lib\MainPage\chat\chats_list_page.dart'
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = re.sub(
        r'<<<<<<< HEAD.*?=======\s*backgroundColor: Colors\.white,\s*body: Container\(\s*child: Column\(\s*children: \[\s*Container\(\s*width: double\.infinity,\s*padding: const EdgeInsets\.only\(left: 16, top: 60, right: 16\),\s*child: Row\(\s*mainAxisAlignment: MainAxisAlignment\.spaceBetween,\s*children: \[\s*Text\(\s*"SkillSwap",\s*style: GoogleFonts\.roboto\(\s*fontSize: 26,\s*fontWeight: FontWeight\.bold,\s*color: Color\(0xFF1E88E5\),\s*\),\s*\),\s*IconButton\(\s*onPressed: \(\) \{\s*Navigator\.push\(\s*context,\s*MaterialPageRoute\(builder: \(_\) => const SupportPage\(\)\)\s*,\s*\);\s*\},\s*icon: const Icon\(Icons\.support_agent_outlined\),\s*color: Colors\.grey\[700\],\s*tooltip: \'support\'\.tr\(\),\s*\)\s*\],\s*>>>>>>> 0697032 \(feat: Add technical support chat page\)\s*\),\s*\),\s*\),\s*\),',
        '''      backgroundColor: Colors.white,
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
          ),''',
        content,
        flags=re.DOTALL
    )

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Replaced successfully" if content != new_content else "No replacements made")
except Exception as e:
    print(f"Error: {e}")
