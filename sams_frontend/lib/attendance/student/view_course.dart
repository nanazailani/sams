import 'package:flutter/material.dart';

class ViewCoursePage extends StatelessWidget {
  const ViewCoursePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      const CourseItem(
        title: 'Differences between generic and\ncustom made',
        fileInfo: '335.0 KB Powerpoint 2007 presentation Uploaded\n4/03/26, 17:25',
        iconData: Icons.insert_drive_file_outlined,
        iconBackground: Color(0xFF42A5F5),
      ),
      const CourseItem(
        title: '[LM][02] Introduction to Software\nEngineering',
        fileInfo: '629.2 KB Powerpoint 2007 presentation Uploaded\n8/03/26, 23:21',
        iconData: Icons.insert_drive_file_outlined,
        iconBackground: Color(0xFF42A5F5),
      ),
      const CourseItem(
        title: '[LS][01] System Project Case Study',
        opened: 'Monday, 16 March 2026, 11:59 PM',
        due: 'Monday, 23 March 2026, 11:59 PM',
        iconData: Icons.upload_file_outlined,
        iconBackground: Color(0xFFE56AA6),
      ),
      const CourseItem(
        title: '[LS][01] SRS Rubric',
        iconData: Icons.insert_drive_file_outlined,
        iconBackground: Color(0xFF42A5F5),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF67C5C4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Course Information',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Nunito',
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.keyboard_arrow_down, size: 34, color: Colors.black87),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Week 1 : 9 March 2026 - 15 March 2026',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _CourseCard(item: item),
                )),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: const Color(0xFFD9D9D9),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseItem item;

  const _CourseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8DDE3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: item.iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.iconData,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ],
          ),

          if (item.fileInfo != null) ...[
            const SizedBox(height: 10),
            Text(
              item.fileInfo!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF667085),
                height: 1.4,
                fontFamily: 'Nunito',
              ),
            ),
          ],
          if (item.opened != null && item.due != null) ...[
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.5,
                        fontFamily: 'Nunito',
                      ),
                      children: [
                        const TextSpan(
                          text: 'Opened: ',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: item.opened!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.5,
                        fontFamily: 'Nunito',
                      ),
                      children: [
                        const TextSpan(
                          text: 'Due: ',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: item.due!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CourseItem {
  final String title;
  final String? fileInfo;
  final String? opened;
  final String? due;
  final IconData iconData;
  final Color iconBackground;

  const CourseItem({
    required this.title,
    required this.iconData,
    required this.iconBackground,
    this.fileInfo,
    this.opened,
    this.due,
  });
}
