import 'package:flutter/material.dart';
import 'package:polyfind/data/models/item_model.dart';
import 'package:polyfind/data/repositories/item_repository.dart';

class ItemTitle extends StatefulWidget {
  const ItemTitle({
    super.key,
    required this.itemId,
    this.fallback = 'Item',
    this.style,
  });

  final String itemId;
  final String fallback;
  final TextStyle? style;

  @override
  State<ItemTitle> createState() => _ItemTitleState();
}

class _ItemTitleState extends State<ItemTitle> {
  late Stream<ItemModel?> _itemStream;

  @override
  void initState() {
    super.initState();
    _itemStream = ItemRepository().watchItem(widget.itemId);
  }

  @override
  void didUpdateWidget(ItemTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) {
      _itemStream = ItemRepository().watchItem(widget.itemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ItemModel?>(
      stream: _itemStream,
      builder: (context, snapshot) => Text(
        snapshot.data?.title ?? widget.fallback,
        style: widget.style,
      ),
    );
  }
}
