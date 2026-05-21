import 'package:flutter/material.dart';

class ViewCoursePageLecturer extends StatelessWidget {
  const ViewCoursePageLecturer({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      const CourseItemLecturer(
        title: 'Differences between generic and\ncustom made',
        fileInfo: '335.0 KB  ·  Powerpoint 2007 presentation\nUploaded 4/03/26, 17:25',
        iconData: Icons.insert_drive_file_outlined,
        iconBackground: Color(0xFF42A5F5),
        type: CourseItemType.file,
      ),
      const CourseItemLecturer(
        title: '[LM][02] Introduction to Software\nEngineering',
        fileInfo: '629.2 KB  ·  Powerpoint 2007 presentation\nUploaded 8/03/26, 23:21',
        iconData: Icons.insert_drive_file_outlined,
        iconBackground: Color(0xFF42A5F5),
        type: CourseItemType.file,
      ),
      const CourseItemLecturer(
        title: '[LS][01] System Project Case Study',
        opened: 'Monday, 16 March 2026, 11:59 PM',
        due: 'Monday, 23 March 2026, 11:59 PM',
        submissionCount: 24,
        iconData: Icons.upload_file_outlined,
        iconBackground: Color(0xFFE56AA6),
        type: CourseItemType.assignment,
      ),
      const CourseItemLecturer(
        title: '[LS][01] SRS Rubric',
        iconData: Icons.insert_drive_file_outlined,
        iconBackground: Color(0xFF42A5F5),
        type: CourseItemType.file,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF67C5C4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Course Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Nunito',
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _showAddWeekDialog(context),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text(
                'Add week',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white24,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week header
            const Row(
              children: [
                Icon(Icons.keyboard_arrow_down, size: 30, color: Colors.black87),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Week 1 : 9 March 2026 - 15 March 2026',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Course item cards
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _LecturerCourseCard(item: item),
                )),

            const SizedBox(height: 4),
            const Divider(color: Color(0xFFD9D9D9)),
            const SizedBox(height: 12),

            // Add material button
            _AddMaterialButton(
              onTap: () => _showAddMaterialDialog(context),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAddWeekDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Week', style: TextStyle(fontFamily: 'Nunito')),
        content: const Text(
          'Add a new week section to the course.',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF67C5C4),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddMaterialDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to Week 1',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 16),
            _BottomSheetOption(
              icon: Icons.insert_drive_file_outlined,
              color: const Color(0xFF42A5F5),
              label: 'Upload File',
              subtitle: 'PDF, Powerpoint, Word, etc.',
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 12),
            _BottomSheetOption(
              icon: Icons.upload_file_outlined,
              color: const Color(0xFFE56AA6),
              label: 'Create Assignment',
              subtitle: 'Set open and due dates',
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Card widget ─────────────────────────────────────────────────────────────

class _LecturerCourseCard extends StatelessWidget {
  final CourseItemLecturer item;

  const _LecturerCourseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8DDE3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.iconData, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    if (item.type == CourseItemType.assignment) ...[
                      const SizedBox(height: 4),
                      _SubmissionBadge(count: item.submissionCount ?? 0),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // File info
          if (item.fileInfo != null) ...[
            const SizedBox(height: 10),
            Text(
              item.fileInfo!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF667085),
                height: 1.4,
                fontFamily: 'Nunito',
              ),
            ),
          ],

          // Assignment due box
          if (item.opened != null && item.due != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DueRow(label: 'Opened:', value: item.opened!),
                  const SizedBox(height: 4),
                  _DueRow(label: 'Due:', value: item.due!),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),

          // Action buttons
          if (item.type == CourseItemType.assignment)
            _AssignmentActions(context: context)
          else
            _FileActions(context: context),
        ],
      ),
    );
  }
}

// ─── Action button rows ───────────────────────────────────────────────────────

class _FileActions extends StatelessWidget {
  final BuildContext context;
  const _FileActions({required this.context});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: Icons.upload_outlined,
          label: 'Replace',
          onTap: () => _showSnack(context, 'Replace file coming soon'),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.drive_file_rename_outline,
          label: 'Rename',
          onTap: () => _showRenameDialog(context),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.delete_outline,
          label: 'Delete',
          isDestructive: true,
          onTap: () => _showDeleteDialog(context),
        ),
      ],
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Nunito'))),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File', style: TextStyle(fontFamily: 'Nunito')),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New file name'),
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF67C5C4),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?', style: TextStyle(fontFamily: 'Nunito')),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AssignmentActions extends StatelessWidget {
  final BuildContext context;
  const _AssignmentActions({required this.context});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.checklist_outlined,
                label: 'Grade',
                isPrimary: true,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening grade view...', style: TextStyle(fontFamily: 'Nunito')),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.people_outline,
                label: 'Submissions',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening submissions...', style: TextStyle(fontFamily: 'Nunito')),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.edit_calendar_outlined,
                label: 'Edit dates',
                onTap: () => _showEditDatesDialog(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                isDestructive: true,
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Assignment?', style: TextStyle(fontFamily: 'Nunito')),
                    content: const Text(
                      'This will also delete all student submissions.',
                      style: TextStyle(fontFamily: 'Nunito'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEditDatesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Dates', style: TextStyle(fontFamily: 'Nunito')),
        content: const Text(
          'Date picker coming soon.',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable small widgets ───────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.white;
    Color fgColor = Colors.black87;
    Color borderColor = const Color(0xFFD8DDE3);

    if (isPrimary) {
      bgColor = const Color(0xFF67C5C4);
      fgColor = Colors.white;
      borderColor = const Color(0xFF67C5C4);
    } else if (isDestructive) {
      fgColor = Colors.red.shade600;
      borderColor = Colors.red.shade200;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fgColor,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  final String label;
  final String value;

  const _DueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
          height: 1.5,
          fontFamily: 'Nunito',
        ),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _SubmissionBadge extends StatelessWidget {
  final int count;
  const _SubmissionBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count submitted',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1565C0),
          fontFamily: 'Nunito',
        ),
      ),
    );
  }
}

class _AddMaterialButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMaterialButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF67C5C4),
            width: 1.5,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFF0FAFA),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_circle_outline, size: 32, color: Color(0xFF67C5C4)),
            SizedBox(height: 6),
            Text(
              'Add material to Week 1',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF67C5C4),
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _BottomSheetOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD8DDE3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Color(0xFF667085)),
          ],
        ),
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

enum CourseItemType { file, assignment }

class CourseItemLecturer {
  final String title;
  final String? fileInfo;
  final String? opened;
  final String? due;
  final int? submissionCount;
  final IconData iconData;
  final Color iconBackground;
  final CourseItemType type;

  const CourseItemLecturer({
    required this.title,
    required this.iconData,
    required this.iconBackground,
    required this.type,
    this.fileInfo,
    this.opened,
    this.due,
    this.submissionCount,
  });
}