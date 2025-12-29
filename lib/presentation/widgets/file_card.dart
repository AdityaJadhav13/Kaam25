import 'package:flutter/material.dart';

import '../../core/utils/file_utils.dart';
import '../../data/models/uploaded_file.dart';

class FileCard extends StatelessWidget {
  const FileCard({
    required this.file,
    this.onTap,
    this.uploaderName,
    this.showUploader = true,
    this.showDate = true,
    this.compact = false,
    super.key,
  });

  final UploadedFile file;
  final VoidCallback? onTap;
  final String? uploaderName;
  final bool showUploader;
  final bool showDate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = FileUtils.iconEmoji(file.type);

    final subtitle = '${file.type.name.toUpperCase()} • ${FileUtils.formatFileSize(file.size)}';

    final metaParts = <String>[];
    if (showUploader && (uploaderName?.isNotEmpty ?? false)) {
      metaParts.add(uploaderName!);
    }
    if (showDate) {
      metaParts.add(MaterialLocalizations.of(context).formatCompactDate(file.uploadedAt));
    }

    final meta = metaParts.join(' • ');

    final cardChild = compact
        ? Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(meta, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: cardChild,
        ),
      ),
    );
  }
}
