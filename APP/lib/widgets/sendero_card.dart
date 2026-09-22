import 'package:flutter/material.dart';

import '../models/explore_trail.dart';
import '../screen/detalle_sendero.dart';

class SenderoCard extends StatelessWidget {
  const SenderoCard({super.key, required this.trail});

  final ExploreTrail trail;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleSenderoScreen(trail: trail),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trail.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                trail.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Publicado por: ${trail.author}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xffeaf5df),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: trail.photoUrl == null
                    ? Image.asset('assets/arbol.jpg', fit: BoxFit.contain)
                    : Image.network(
                        trail.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Image.asset(
                          'assets/arbol.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    trail.difficulty,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text('${trail.distanceKm.toStringAsFixed(1)} km'),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
