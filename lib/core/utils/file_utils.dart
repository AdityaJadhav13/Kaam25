import '../../data/models/enums.dart';

abstract final class FileUtils {
  static String extensionOf(String filename) {
    final parts = filename.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase();
  }

  static FileType? fileTypeFromName(String filename) {
    return switch (extensionOf(filename)) {
      'pdf' => FileType.pdf,
      'doc' => FileType.doc,
      'docx' => FileType.docx,
      'ppt' => FileType.ppt,
      'pptx' => FileType.pptx,
      'xls' => FileType.xls,
      'xlsx' => FileType.xlsx,
      'txt' => FileType.txt,
      'jpg' => FileType.jpg,
      'jpeg' => FileType.jpeg,
      'png' => FileType.png,
      'mp4' => FileType.mp4,
      'mov' => FileType.mov,
      _ => null,
    };
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 Bytes';
    const k = 1024;
    const units = ['Bytes', 'KB', 'MB', 'GB'];
    var i = 0;
    var value = bytes.toDouble();
    while (value >= k && i < units.length - 1) {
      value /= k;
      i++;
    }
    final rounded = (value * 100).round() / 100;
    return '$rounded ${units[i]}';
  }

  static String iconEmoji(FileType type) {
    switch (type) {
      case FileType.jpg:
      case FileType.jpeg:
      case FileType.png:
        return '🖼️';
      case FileType.mp4:
      case FileType.mov:
        return '🎥';
      case FileType.pdf:
        return '📄';
      case FileType.doc:
      case FileType.docx:
        return '📝';
      case FileType.ppt:
      case FileType.pptx:
        return '📊';
      case FileType.xls:
      case FileType.xlsx:
        return '📈';
      case FileType.txt:
        return '📃';
    }
  }
}
