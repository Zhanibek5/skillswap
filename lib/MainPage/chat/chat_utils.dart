String generateChatId(String id1, String id2) {
  return id1.hashCode <= id2.hashCode ? '${id1}_$id2' : '${id2}_$id1';
}
