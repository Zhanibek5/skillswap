import sys
import re

with open('F:\skillswap\lib\MainPage\profilePage\profile_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix initUserStatus
content = content.replace("'balance': 2,", "'balance': 120, // in minutes")
content = content.replace("final rating = (data['ratingAverage'] ?? 0).toDouble();", "final rating = (data['ratingAverage'] ?? 0).toDouble();\n              final int balanceMinutes = (data['balance'] ?? 120);\n              final int timeEarned = (data['timeEarned'] ?? 0);\n              final int timeSpent = (data['timeSpent'] ?? 0);\n")

# Replace old statItem for balance
content = content.replace("_statItem('?', '2h', 'balance'.tr()),", "_statItem('?', '\h \m', 'balance'.tr()),")

with open('F:\skillswap\lib\MainPage\profilePage\profile_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
