import os

with open('lib/MainPage/skillMain.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('color: isSelected\n              ? primaryColor', 'color: isSelected\n              ? (isDark ? Colors.white.withOpacity(0.15) : const Color(0xFF1E88E5))')

text = text.replace('color: isSelected\n                    ? Colors.black', 'color: isSelected\n                    ? Colors.white')

text = text.replace('color: Colors.black,\n                          fontSize: 11', 'color: Colors.white,\n                          fontSize: 11')

if 'color: isSelected ? Colors.white' not in text:
    text = text.replace('color: isSelected \n                    ? Colors.black ', 'color: isSelected \n                    ? Colors.white ')

with open('lib/MainPage/skillMain.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print('done')
