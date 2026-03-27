import sys

with open('f:\\skillswap\\lib\\MainPage\\profilePage\\profile_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    
    if "child: ElevatedButton.icon(" in line and "onPressed: () {" in lines[i+1] and "Navigator.push(" in lines[i+2] and "context," in lines[i+3] and "MaterialPageRoute(" in lines[i+4]:
        # Aha! ElevatedButton.icon doesn't take positional arguments in modern flutter flutter 3.3+.
        print("MISTAKE.")
