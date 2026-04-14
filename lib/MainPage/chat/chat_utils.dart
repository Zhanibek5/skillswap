String generateChatId(String id1, String id2) {
  final list = [id1, id2]..sort();
  return '${list[0]}_${list[1]}';
}
