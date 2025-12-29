import '../models/announcement.dart';
import '../models/enums.dart';
import '../models/folder.dart';
import '../models/kaam_user.dart';
import '../models/message.dart';
import '../models/note.dart';
import '../models/story.dart';

abstract final class MockData {
  static final users = <KaamUser>[
    KaamUser(
      id: '1',
      email: 'admin@kaam25.com',
      name: 'Admin User',
      status: UserStatus.approved,
      role: UserRole.admin,
      createdAt: DateTime.parse('2024-01-01'),
    ),
    KaamUser(
      id: '2',
      email: 'john@kaam25.com',
      name: 'John Doe',
      status: UserStatus.approved,
      role: UserRole.member,
      createdAt: DateTime.parse('2024-01-15'),
    ),
    KaamUser(
      id: '3',
      email: 'sarah@kaam25.com',
      name: 'Sarah Smith',
      status: UserStatus.approved,
      role: UserRole.member,
      createdAt: DateTime.parse('2024-02-01'),
    ),
    KaamUser(
      id: '4',
      email: 'mike@kaam25.com',
      name: 'Mike Johnson',
      status: UserStatus.approved,
      role: UserRole.member,
      createdAt: DateTime.parse('2024-02-10'),
    ),
  ];

  // Mock folders removed - using real Firestore data now
  static final folders = <Folder>[];

  static final notes = <Note>[
    Note(
      id: '1',
      folderId: '1',
      title: 'Project Overview',
      content:
          'This document outlines the key objectives and milestones for the project...',
      authorId: '1',
      createdAt: DateTime.parse('2024-12-01'),
      updatedAt: DateTime.parse('2024-12-20'),
      isNew: true,
    ),
    Note(
      id: '2',
      folderId: '1',
      title: 'Code of Conduct',
      content:
          'All team members are expected to maintain professional behavior...',
      authorId: '1',
      createdAt: DateTime.parse('2024-11-15'),
      updatedAt: DateTime.parse('2024-11-15'),
      isNew: false,
    ),
    Note(
      id: '3',
      folderId: '3',
      title: 'Weekly Sync - Dec 20',
      content:
          'Attendees: Admin, John, Sarah\n\nAgenda:\n1. Progress updates\n2. Blockers\n3. Next steps',
      authorId: '2',
      createdAt: DateTime.parse('2024-12-20'),
      updatedAt: DateTime.parse('2024-12-20'),
      isNew: true,
    ),
  ];

  // Mock announcements removed - using Firestore implementation
  static final announcements = <Announcement>[];

  static final messages = <Message>[
    Message(
      id: '1',
      authorId: '2',
      content:
          'Hey everyone! Just uploaded the latest project files to the Technical Docs folder.',
      timestamp: DateTime.parse('2024-12-27T09:30:00'),
      isEdited: false,
      readBy: const ['1', '3', '4'],
    ),
    Message(
      id: '2',
      authorId: '3',
      content: "Thanks John! I'll review them this afternoon.",
      timestamp: DateTime.parse('2024-12-27T09:45:00'),
      isEdited: false,
      readBy: const ['1', '2', '4'],
    ),
    Message(
      id: '3',
      authorId: '1',
      content:
          "Great work team! Don't forget about the announcement regarding system maintenance tomorrow.",
      timestamp: DateTime.parse('2024-12-27T10:15:00'),
      isEdited: false,
      readBy: const ['2', '3'],
    ),
    Message(
      id: '4',
      authorId: '4',
      content: "Noted! I've already saved my work locally.",
      timestamp: DateTime.parse('2024-12-27T10:20:00'),
      isEdited: false,
      readBy: const ['1', '2'],
    ),
  ];

  static final stories = <Story>[
    Story(
      id: '1',
      authorId: '2',
      content: 'Working on the new feature! 🚀',
      type: StoryType.text,
      createdAt: DateTime.parse('2024-12-27T08:00:00'),
      expiresAt: DateTime.parse('2024-12-28T08:00:00'),
      viewedBy: const ['1', '3'],
    ),
    Story(
      id: '2',
      authorId: '3',
      content: 'Coffee break ☕',
      type: StoryType.text,
      createdAt: DateTime.parse('2024-12-27T11:30:00'),
      expiresAt: DateTime.parse('2024-12-28T11:30:00'),
      viewedBy: const ['1'],
    ),
  ];
}
