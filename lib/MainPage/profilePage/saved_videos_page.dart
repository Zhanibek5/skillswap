import 'package:flutter/material.dart';

class SavedVideosPage extends StatefulWidget {
  const SavedVideosPage({super.key});

  @override
  State<SavedVideosPage> createState() => _SavedVideosPageState();
}

class _SavedVideosPageState extends State<SavedVideosPage> {
  // TEMP MOCK DATA (кейін Firestore-дан келеді)
  final List<Map<String, String>> videos = [
    {
      'thumbnail': 'https://picsum.photos/300/200?1',
      'title': 'English Lesson',
      'duration': '45 min',
    },
    {
      'thumbnail': 'https://picsum.photos/300/200?2',
      'title': 'UI/UX Design',
      'duration': '60 min',
    },
    {
      'thumbnail': 'https://picsum.photos/300/200?3',
      'title': 'Flutter Basics',
      'duration': '30 min',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Saved Lessons'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _background(),
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              return _videoCard(videos[index]);
            },
          ),
        ],
      ),
    );
  }

  // 🌈 BACKGROUND (СЕНІҢ ГРАДИЕНТІҢ)
  Widget _background() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [
            0.0,
            0.10,
            0.15,
            0.35,
            0.45,
            0.58,
            1.0,
          ],
          colors: [
            Color(0xFF3594DD),
            Color(0xFF5036D5),
            Color(0xFF5B16D0),
            Color(0xFF7A5DE8),
            Color(0xFFB8B0F5),
            Color(0xFFF2F1FD),
            Colors.white,
          ],
        ),
      ),
    );
  }

  // 🎥 VIDEO CARD
  Widget _videoCard(Map<String, String> video) {
    return GestureDetector(
      onTap: () {
        // TODO: open video player
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼 THUMBNAIL
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    video['thumbnail']!,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const Positioned(
                  bottom: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.play_arrow, color: Colors.white),
                  ),
                ),
              ],
            ),

            // 📄 INFO
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video['duration']!,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          videos.remove(video);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
