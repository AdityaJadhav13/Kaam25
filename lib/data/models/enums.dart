enum UserStatus { approved, pending, blocked }

enum UserRole { member, admin }

enum AnnouncementType { normal, important, urgent }

enum StoryType { text, image, video }

enum FileType {
  pdf,
  doc,
  docx,
  ppt,
  pptx,
  xls,
  xlsx,
  txt,
  jpg,
  jpeg,
  png,
  mp4,
  mov,
}

enum FileContext { note, announcement, chat }

enum UploadStatus { pending, uploading, completed, failed }

extension EnumParsing on String {
  UserStatus? toUserStatus() {
    switch (this) {
      case 'approved':
        return UserStatus.approved;
      case 'pending':
        return UserStatus.pending;
      case 'blocked':
        return UserStatus.blocked;
    }
    return null;
  }

  UserRole? toUserRole() {
    switch (this) {
      case 'member':
        return UserRole.member;
      case 'admin':
        return UserRole.admin;
    }
    return null;
  }

  AnnouncementType? toAnnouncementType() {
    switch (this) {
      case 'normal':
        return AnnouncementType.normal;
      case 'important':
        return AnnouncementType.important;
      case 'urgent':
        return AnnouncementType.urgent;
    }
    return null;
  }

  StoryType? toStoryType() {
    switch (this) {
      case 'text':
        return StoryType.text;
      case 'image':
        return StoryType.image;
      case 'video':
        return StoryType.video;
    }
    return null;
  }

  FileType? toFileType() {
    switch (this) {
      case 'pdf':
        return FileType.pdf;
      case 'doc':
        return FileType.doc;
      case 'docx':
        return FileType.docx;
      case 'ppt':
        return FileType.ppt;
      case 'pptx':
        return FileType.pptx;
      case 'xls':
        return FileType.xls;
      case 'xlsx':
        return FileType.xlsx;
      case 'txt':
        return FileType.txt;
      case 'jpg':
        return FileType.jpg;
      case 'jpeg':
        return FileType.jpeg;
      case 'png':
        return FileType.png;
      case 'mp4':
        return FileType.mp4;
      case 'mov':
        return FileType.mov;
    }
    return null;
  }

  FileContext? toFileContext() {
    switch (this) {
      case 'note':
        return FileContext.note;
      case 'announcement':
        return FileContext.announcement;
      case 'chat':
        return FileContext.chat;
    }
    return null;
  }

  UploadStatus? toUploadStatus() {
    switch (this) {
      case 'pending':
        return UploadStatus.pending;
      case 'uploading':
        return UploadStatus.uploading;
      case 'completed':
        return UploadStatus.completed;
      case 'failed':
        return UploadStatus.failed;
    }
    return null;
  }
}

extension EnumToWire on Enum {
  String get wire {
    // matches TypeScript unions in the reference export
    return name;
  }
}
