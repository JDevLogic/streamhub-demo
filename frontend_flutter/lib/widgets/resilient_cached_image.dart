import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

List<String> buildImageCandidates(String rawUrl) {
  final url = rawUrl.trim();
  if (url.isEmpty) return const [];

  String normalized = url;
  if (normalized.startsWith('//')) {
    normalized = 'https:$normalized';
  }

  final out = <String>{normalized};
  Uri? uri;
  try {
    uri = Uri.parse(normalized);
  } catch (_) {
    return out.toList();
  }






  }

  return out.toList();
}

class ResilientCachedImage extends StatefulWidget {
  const ResilientCachedImage({
    super.key,
    required this.imageUrl,
    required this.fit,
    required this.httpHeaders,
    required this.placeholder,
    required this.fallback,
  });

  final String imageUrl;
  final BoxFit fit;
  final Map<String, String> httpHeaders;
  final Widget placeholder;
  final Widget fallback;

  @override
  State<ResilientCachedImage> createState() => _ResilientCachedImageState();
}

class _ResilientCachedImageState extends State<ResilientCachedImage> {
  late List<String> _candidates;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _candidates = buildImageCandidates(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant ResilientCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _candidates = buildImageCandidates(widget.imageUrl);
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) return widget.fallback;

    return CachedNetworkImage(
      imageUrl: _candidates[_index],
      fit: widget.fit,
      httpHeaders: widget.httpHeaders,
      fadeInDuration: const Duration(milliseconds: 400),
      fadeOutDuration: const Duration(milliseconds: 300),
      placeholder: (_, __) => widget.placeholder,
      errorWidget: (_, __, ___) {
        if (_index < _candidates.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index += 1);
          });
          return widget.placeholder;
        }
        return widget.fallback;
      },
    );
  }
}

