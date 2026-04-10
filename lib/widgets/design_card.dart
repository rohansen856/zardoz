import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/design.dart';
import '../services/api_service.dart';

class DesignCard extends StatefulWidget {
  final Design design;
  final VoidCallback? onChanged;
  final bool showDelete;

  const DesignCard({
    super.key,
    required this.design,
    this.onChanged,
    this.showDelete = false,
  });

  @override
  State<DesignCard> createState() => _DesignCardState();
}

class _DesignCardState extends State<DesignCard> {
  final _api = ApiService();

  @override
  Widget build(BuildContext context) {
    final d = widget.design;
    final imageUrl = d.imageUrl;
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(context, '/design', arguments: d.id);
          widget.onChanged?.call();
        },
        child: Row(
          children: [
            // Thumbnail
            Hero(
              tag: 'design_${d.id}',
              child: SizedBox(
                width: 110,
                height: 110,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('by ${d.authorName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Save chip
                        _Chip(
                          icon: d.isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          label: 'Save',
                          active: d.isSaved,
                          onTap: () async {
                            final res = await _api.toggleSave(d.id);
                            setState(() => d.isSaved = res);
                            widget.onChanged?.call();
                          },
                        ),
                        const SizedBox(width: 8),
                        // Project chip
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/project', arguments: {
                              'imageUrl': imageUrl,
                              'title': d.title,
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: primary),
                            ),
                            child: Text('Project',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: primary)),
                          ),
                        ),
                        if (widget.showDelete) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Design'),
                                  content: const Text('Remove this design permanently?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete',
                                            style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await _api.deleteDesign(d.id);
                                widget.onChanged?.call();
                              }
                            },
                            child: Icon(Icons.delete_outline,
                                size: 20, color: Colors.red[300]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? primary.withAlpha(20) : Colors.grey[100],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? primary : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: active ? primary : Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
