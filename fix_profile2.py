import sys

with open('F:\skillswap\lib\MainPage\profilePage\profile_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_time_bank = '''                        // ===== TIME BANK =====
                        _sectionTitle('time_bank'.tr()),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: _boxDecoration(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('earned'.tr()),
                                    SizedBox(width: 4),
                                    Text(
                                      '0h',
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('spent'.tr()),
                                    SizedBox(width: 4),
                                    Text('0h'),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('balance:'.tr(),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Text('0h',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            )),'''

new_time_bank = '''                        // ===== TIME BANK =====
                        _sectionTitle('time_bank'.tr()),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: _boxDecoration(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.arrow_upward, color: Colors.green, size: 16),
                                    const SizedBox(width: 4),
                                    Text('earned'.tr()),
                                    const SizedBox(width: 4),
                                    Text('\h \m', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.arrow_downward, color: Colors.red, size: 16),
                                    const SizedBox(width: 4),
                                    Text('spent'.tr()),
                                    const SizedBox(width: 4),
                                    Text('\h \m', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet, color: Color(0xFF1E88E5), size: 16),
                                    const SizedBox(width: 4),
                                    Text('balance:'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    Text('\h \m', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
                                  ],
                                ),
                              ],
                            )),'''

content = content.replace(old_time_bank, new_time_bank)

with open('F:\skillswap\lib\MainPage\profilePage\profile_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
