import 'package:flutter/material.dart';
import '../models/content_item.dart';
import 'poster_card.dart';

class ContentCarousel extends StatelessWidget {
  final List<ContentItem> items;

  const ContentCarousel({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 130,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PosterCard(
                    posterUrl: item.posterUrl,
                    title: item.title,
                    id: item.playbackId,
                    mediaType: item.type,
                    year: item.year,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (item.year != null)
                  Text(
                    item.year!,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
