import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/widgets.dart';

/// Server-side limits, mirrored here so the user hears about a problem before
/// waiting for an upload. The server still enforces them.
const maxFilesPerReport = 10;
const maxFileBytes = 10 * 1024 * 1024;

/// A file on this device that is waiting to be uploaded.
class Attachment {
  const Attachment({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.size,
  });

  final String path;
  final String name;
  final String mimeType;
  final int size;

  bool get isImage => mimeType.startsWith('image/');
}

/// The upload types the server accepts, by file extension.
String? mimeTypeForName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' || 'heif' => 'image/heic',
    'pdf' => 'application/pdf',
    _ => null,
  };
}

enum _Source { camera, gallery, pdf }

/// image_picker prefixes resized photos with "scaled_"; show the real name.
String _originalName(String name) =>
    name.startsWith('scaled_') ? name.substring('scaled_'.length) : name;

/// Asks where to get files from (camera, gallery or a PDF), lets the user pick,
/// and returns the usable ones. Files that are too big, of the wrong type, or
/// beyond [remaining] free slots are dropped with a message.
Future<List<Attachment>> pickAttachments(
  BuildContext context, {
  required int remaining,
}) async {
  if (remaining <= 0) {
    showMessage(context, 'A report can have at most $maxFilesPerReport files.');
    return const [];
  }

  final source = await showModalBottomSheet<_Source>(
    context: context,
    showDragHandle: true,
    builder:
        (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, _Source.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose photos'),
                onTap: () => Navigator.pop(context, _Source.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Choose a PDF'),
                onTap: () => Navigator.pop(context, _Source.pdf),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
  );
  if (source == null) return const [];

  // (path, display name) of everything the user picked.
  final picked = <(String, String)>[];
  try {
    final images = ImagePicker();
    switch (source) {
      case _Source.camera:
        // Downscale and re-encode: phone photos are far larger than a
        // readable document needs, and uploads are capped at 10 MB.
        final photo = await images.pickImage(
          source: ImageSource.camera,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 85,
        );
        // The camera names files with a random id; use the time instead.
        if (photo != null) {
          final ext =
              photo.name.contains('.') ? photo.name.split('.').last : 'jpg';
          final stamp = DateFormat(
            'yyyy-MM-dd HH.mm.ss',
          ).format(DateTime.now());
          picked.add((photo.path, 'Photo $stamp.$ext'));
        }
      case _Source.gallery:
        final photos = await images.pickMultiImage(
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 85,
        );
        picked.addAll(photos.map((p) => (p.path, _originalName(p.name))));
      case _Source.pdf:
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: true,
        );
        for (final file in result?.files ?? const <PlatformFile>[]) {
          if (file.path != null) picked.add((file.path!, file.name));
        }
    }
  } on PlatformException catch (e) {
    if (context.mounted) {
      showMessage(
        context,
        e.code.contains('denied')
            ? 'Permission was denied. Allow it in your phone settings.'
            : 'Could not open the picker. ${e.message ?? ''}',
      );
    }
    return const [];
  }

  final accepted = <Attachment>[];
  final problems = <String>{};
  for (final (path, name) in picked) {
    final mimeType = mimeTypeForName(name) ?? mimeTypeForName(path);
    final size = await File(path).length();
    if (mimeType == null) {
      problems.add('Only photos and PDFs can be uploaded.');
    } else if (size > maxFileBytes) {
      problems.add('Files over 10 MB were skipped.');
    } else if (accepted.length >= remaining) {
      problems.add('Only $maxFilesPerReport files fit in one report.');
    } else {
      accepted.add(
        Attachment(path: path, name: name, mimeType: mimeType, size: size),
      );
    }
  }
  if (problems.isNotEmpty && context.mounted) {
    showMessage(context, problems.join(' '));
  }
  return accepted;
}
