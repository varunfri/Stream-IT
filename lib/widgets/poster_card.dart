import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A reusable poster card.
/// • Tap  → opens full-screen poster dialog with a "Details" button.
/// • Long-press is forwarded to [onLongPress] (optional).
class PosterCard extends StatelessWidget {
  final String? posterUrl;
  final String title;
  final String id;
  final String mediaType; // 'movie' or 'tv'
  final String? year;
  final double width;
  final double height;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const PosterCard({
    super.key,
    required this.posterUrl,
    required this.title,
    required this.id,
    required this.mediaType,
    this.year,
    this.width = 120,
    this.height = 180,
    this.onLongPress,
    this.onTap,
    this.onDelete,
  });

  void _showEnlarged(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Poster ──────────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, _) => const AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFE50914),
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Container(
                            color: const Color(0xFF1E1E1E),
                            child: const Icon(Icons.broken_image, size: 60),
                          ),
                        ),
                      )
                    : AspectRatio(
                        aspectRatio: 2 / 3,
                        child: Container(
                          color: const Color(0xFF1E1E1E),
                          child: const Icon(Icons.movie, size: 60),
                        ),
                      ),
              ),

              // ── Bottom gradient + buttons ────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black, Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 32, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (year != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            year!,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE50914),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(Icons.info_outline, size: 18),
                                label: const Text('Details'),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  context.push('/details/$mediaType/$id');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('Play'),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  context.push('/player/$mediaType/$id');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Close button ─────────────────────────────────────────────
              Positioned(
                top: -14,
                right: -14,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidget = GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!();
        }
        _showEnlarged(context);
      },
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: posterUrl != null && posterUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: posterUrl!,
                  fit: BoxFit.cover,
                  width: width,
                  height: height,
                  placeholder: (_, _) => Container(
                    color: const Color(0xFF1E1E1E),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE50914),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: const Color(0xFF1E1E1E),
                    child: const Icon(Icons.movie),
                  ),
                )
              : Container(
                  color: const Color(0xFF1E1E1E),
                  child: const Icon(Icons.movie),
                ),
        ),
      ),
    );

    if (onDelete != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          cardWidget,
          Positioned(
            top: -2,
            right: 0,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xE6E50914), // Netflix Red!
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      );
    }

    return cardWidget;
  }
}
