import 'dart:typed_data';

import 'package:polyfind/core/constants/app_constants.dart';
import 'package:polyfind/data/models/item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ItemRepository {
  ItemRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<ItemModel?> watchItem(String id) {
    return _client
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) => rows.isEmpty ? null : ItemModel.fromJson(rows.first));
  }

  Stream<List<ItemModel>> watchItems(String type) {
    return _client
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('type', type)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .where((row) => row['status'] == AppConstants.itemStatusOpen)
              .map(ItemModel.fromJson)
              .toList(growable: false),
        );
  }

  Stream<List<ItemModel>> watchItemsByOwner(String userId) {
    return _client
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('posted_by', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ItemModel.fromJson).toList(growable: false));
  }

  Future<String> uploadItemImage({
    required String userId,
    required Uint8List bytes,
  }) async {
    if (bytes.length >= AppConstants.maxItemImageBytes) {
      throw StateError('The compressed photo must be smaller than 300 KB.');
    }

    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from(AppConstants.itemPhotosBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    return path;
  }

  Future<void> deleteItemImage(String imagePath) async {
    await _client.storage
        .from(AppConstants.itemPhotosBucket)
        .remove([imagePath]);
  }

  Future<void> markItemReturned(String itemId) async {
    await _client
        .from('items')
        .update({'status': AppConstants.itemStatusReturned}).eq('id', itemId);
  }

  Future<void> createItem({
    required String type,
    required String title,
    required String description,
    required String category,
    required String location,
    required DateTime date,
    required String postedBy,
    String? heldAt,
    String? imagePath,
  }) async {
    await _client.from('items').insert({
      'type': type,
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'date': date.toIso8601String(),
      'image_path': imagePath,
      'status': AppConstants.itemStatusOpen,
      'posted_by': postedBy,
      'held_at': heldAt,
    });
  }
}
