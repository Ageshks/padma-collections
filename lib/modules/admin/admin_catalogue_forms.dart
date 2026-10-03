import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/cloudinary_config.dart';
import '../../core/services/cloudinary_image_service.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_network_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/product_repository.dart';

class AdminProductFormView extends StatefulWidget {
  const AdminProductFormView({super.key, this.product});

  final ProductModel? product;

  @override
  State<AdminProductFormView> createState() => _AdminProductFormViewState();
}

class _AdminProductFormViewState extends State<AdminProductFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late final ProductRepository _products;
  late final CategoryRepository _categories;
  late final Future<List<CategoryModel>> _categoryFuture;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _compareAtPrice;
  late final TextEditingController _stock;
  late final TextEditingController _sku;
  late final TextEditingController _material;
  late final TextEditingController _color;
  late final TextEditingController _size;
  late final TextEditingController _weight;
  late String _categoryId;

  /// Images already stored in Cloudinary, in gallery order.
  late List<CloudinaryImage> _images;

  /// Photos picked but not yet uploaded. Held locally so the admin can review
  /// the selection before anything leaves the device.
  final List<XFile> _pendingImages = <XFile>[];

  /// Files that failed to upload, kept so "Retry" re-sends exactly those
  /// rather than making the admin re-pick everything.
  final List<XFile> _failedImages = <XFile>[];

  bool _isActive = true;
  bool _isAvailable = true;
  bool _isNewArrival = false;
  bool _isFastMoving = false;
  bool _isFeatured = false;
  bool _saving = false;
  bool _uploading = false;

  /// Progress of the in-flight upload, or null when idle.
  ImageUploadProgress? _progress;

  /// Images removed in this session but not yet persisted.
  ///
  /// Held so that a cancelled save can put them back (§18), then dropped on
  /// save. Note their Cloudinary assets survive either way — the app cannot
  /// delete — so this list tracks *intent*, not reclaimed storage.
  final List<CloudinaryImage> _removedImages = <CloudinaryImage>[];

  @override
  void initState() {
    super.initState();
    _products = Get.find<ProductRepository>();
    _categories = Get.find<CategoryRepository>();
    _categoryFuture = _categories.watchAllCategories().first;
    final ProductModel? product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _price = TextEditingController(text: product?.price.toString() ?? '');
    _compareAtPrice = TextEditingController(
      text: product == null || product.compareAtPrice == 0
          ? ''
          : product.compareAtPrice.toString(),
    );
    _stock = TextEditingController(text: product?.stock.toString() ?? '0');
    _sku = TextEditingController(text: product?.sku ?? '');
    _material = TextEditingController(text: product?.material ?? '');
    _color = TextEditingController(text: product?.color ?? '');
    _size = TextEditingController(text: product?.size ?? '');
    _weight = TextEditingController(text: product?.weight ?? '');
    _categoryId = product?.categoryId ?? '';
    _images = List<CloudinaryImage>.of(
      product?.images ?? const <CloudinaryImage>[],
    );
    _isActive = product?.isActive ?? true;
    _isAvailable = product?.isAvailable ?? true;
    _isNewArrival = product?.isNewArrival ?? false;
    _isFastMoving = product?.isFastMoving ?? false;
    _isFeatured = product?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _compareAtPrice.dispose();
    _stock.dispose();
    _sku.dispose();
    _material.dispose();
    _color.dispose();
    _size.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Adds photos to the pending queue, respecting the per-product cap.
  Future<void> _pickImages() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage();
      if (files.isEmpty || !mounted) return;

      final int room = CloudinaryConfig.maxProductImages - _totalImages;
      if (room <= 0) {
        _showAdminMessage(
          'A product can have up to '
          '${CloudinaryConfig.maxProductImages} photos.',
          error: true,
        );
        return;
      }

      final List<XFile> accepted = files.take(room).toList();
      final int rejected = files.length - accepted.length;

      setState(() => _pendingImages.addAll(accepted));
      await _uploadPendingImages();
      if (rejected > 0) {
        _showAdminMessage(
          '$rejected photo(s) skipped — the limit is '
          '${CloudinaryConfig.maxProductImages}.',
          error: true,
        );
      }
    } catch (_) {
      _showAdminMessage('Could not open the photo picker.', error: true);
    }
  }

  /// Stored + pending photos currently attached to this product.
  int get _totalImages => _images.length + _pendingImages.length;

  /// Uploads every pending (and previously failed) photo to Cloudinary.
  ///
  /// Returns true when nothing is left in a failed state. The product document
  /// is only written once this succeeds, so a product is never saved pointing
  /// at images that do not exist (§30).
  Future<bool> _uploadPendingImages() async {
    if (_pendingImages.isEmpty && _failedImages.isEmpty) return true;

    if (!Get.isRegistered<CloudinaryImageService>()) {
      _showAdminMessage(
        'Image service is unavailable. Please restart the app.',
        error: true,
      );
      return false;
    }

    final CloudinaryImageService images = Get.find<CloudinaryImageService>();
    final String productId =
        widget.product?.productId ??
        'draft-${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _uploading = true;
      _progress = null;
    });

    final List<XFile> batch = <XFile>[..._failedImages, ..._pendingImages];

    try {
      final ImageUploadResult result = await images.uploadImages(
        batch,
        type: CloudinaryImageService.typeProducts,
        entityId: productId,
        onProgress: (ImageUploadProgress p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return false;

      final Set<String> failedNames = result.failedFileNames.toSet();
      setState(() {
        _images = CloudinaryImage.normalised(<CloudinaryImage>[
          ..._images,
          ...result.uploaded,
        ]);
        // Anything that did not upload stays queued for a retry.
        _failedImages
          ..clear()
          ..addAll(batch.where((XFile f) => failedNames.contains(f.name)));
        _pendingImages.clear();
        _uploading = false;
        _progress = null;
      });

      if (result.allSucceeded) {
        _showAdminMessage('${result.uploaded.length} image(s) uploaded.');
        return true;
      }

        final String reason = result.failureMessages.isEmpty
          ? 'Please try again.'
          : result.failureMessages.first;
        _showAdminMessage('Image upload failed: $reason Tap retry.', error: true);
      return false;
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = null;
        });
      }
      _showAdminMessage(e.message, error: true);
      return false;
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = null;
        });
      }
      _showAdminMessage(AppErrorHandler.wrap(e).message, error: true);
      return false;
    }
  }

  /// Re-uploads only the photos that previously failed.
  Future<void> _retryFailedUploads() => _uploadPendingImages();

  /// Marks the image at [index] as the primary (card + gallery) photo.
  void _setPrimary(int index) {
    setState(() => _images = CloudinaryImage.withPrimary(_images, index));
  }

  /// Moves an image, keeping the gallery order the admin sees.
  void _reorder(int from, int to) {
    if (from == to) return;
    setState(() => _images = CloudinaryImage.reordered(_images, from, to));
  }

  /// Removes an image from the product.
  ///
  /// The Firestore copy is dropped on save. The Cloudinary asset is **not**
  /// deleted — unsigned uploads cannot delete, so it lingers in the Media
  /// Library until swept by hand. It is tracked in [_removedImages] so the
  /// removal is not mistaken for a reclaim, and so the admin's intent survives
  /// a cancelled save (§18) before it is finally persisted.
  void _removeImage(int index) {
    final CloudinaryImage removed = _images[index];
    setState(() {
      _images = CloudinaryImage.normalised(
        List<CloudinaryImage>.of(_images)..removeAt(index),
      );
      if (!removed.isExternal) _removedImages.add(removed);
    });
  }

  Future<void> _save() async {
    if (_saving || _uploading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Images first: a product must never reference an image that failed to
    // upload, so the upload has to succeed before anything is written (§30).
    final bool imagesReady = await _uploadPendingImages();
    if (!imagesReady) return;

    setState(() => _saving = true);
    try {
      final DateTime now = DateTime.now();
      final List<CloudinaryImage> ordered = CloudinaryImage.normalised(
        _images.take(CloudinaryConfig.maxProductImages).toList(),
      );
      final ProductModel draft = ProductModel(
        productId: widget.product?.productId ?? '',
        name: _name.text.trim(),
        description: _description.text.trim(),
        categoryId: _categoryId,
        categoryName: _categoryName,
        images: ordered,
        price: double.parse(_price.text.trim()),
        compareAtPrice: double.tryParse(_compareAtPrice.text.trim()) ?? 0,
        stock: int.parse(_stock.text.trim()),
        sku: _sku.text.trim(),
        material: _material.text.trim(),
        color: _color.text.trim(),
        size: _size.text.trim(),
        weight: _weight.text.trim(),
        isAvailable: _isAvailable,
        isFeatured: _isFeatured,
        isFastMoving: _isFastMoving,
        isNewArrival: _isNewArrival,
        isActive: _isActive,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
      );

      final String productId;
      if (widget.product == null) {
        productId = await _products.create(draft);
      } else {
        productId = widget.product!.productId;
        await _products.update(productId, draft);
      }

      // Images the admin dropped are no longer referenced by this document.
      // This call is a no-op while uploads are unsigned (Cloudinary's delete
      // needs the API secret), but it is kept so that reinstating real deletes
      // later is a matter of deploying the function — no call-site changes.
      // Note the admin is not told storage was reclaimed, because it was not.
      if (_removedImages.isNotEmpty &&
          Get.isRegistered<CloudinaryImageService>()) {
        await Get.find<CloudinaryImageService>().deleteImages(
          _removedImages.map((CloudinaryImage i) => i.publicId),
        );
        _removedImages.clear();
      }

      try {
        final List<ProductModel> currentProducts = await _products
            .watchAllProducts()
            .first;
        await _categories.refreshCounts(currentProducts);
      } catch (_) {
        // The product save succeeds independently of the denormalized counts.
      }

      if (!mounted) return;
      Get.back<void>();
      _showAdminMessage('Product saved.');
    } on AppException catch (e) {
      _showAdminMessage(e.message, error: true);
    } catch (e) {
      _showAdminMessage(AppErrorHandler.wrap(e).message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _categoryName =>
      _categoriesForForm
          .firstWhereOrNull(
            (CategoryModel category) => category.categoryId == _categoryId,
          )
          ?.name ??
      '';

  List<CategoryModel> _categoriesForForm = const <CategoryModel>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add product' : 'Edit product'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Save product',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<CategoryModel>>(
        future: _categoryFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<CategoryModel>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _AdminLoadError(
                  message: 'Could not load categories: ${snapshot.error}',
                );
              }
              _categoriesForForm = snapshot.data ?? const <CategoryModel>[];
              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                      ),
                      validator: (String? value) =>
                          AppValidators.name(value, field: 'Product name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _categoriesForForm.any(
                            (CategoryModel item) =>
                                item.categoryId == _categoryId,
                          )
                          ? _categoryId
                          : null,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categoriesForForm
                          .map(
                            (CategoryModel item) => DropdownMenuItem<String>(
                              value: item.categoryId,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) =>
                          setState(() => _categoryId = value ?? ''),
                      validator: (String? value) =>
                          AppValidators.required(value, field: 'Category'),
                    ),
                    if (_categoriesForForm.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'Create a category before adding products.',
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                            ),
                            validator: AppValidators.price,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _compareAtPrice,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Compare-at price',
                            ),
                            validator: (String? value) =>
                                value == null || value.trim().isEmpty
                                ? null
                                : AppValidators.price(
                                    value,
                                    field: 'Compare-at price',
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _stock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stock',
                            ),
                            validator: AppValidators.stock,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _sku,
                            decoration: const InputDecoration(labelText: 'SKU'),
                            validator: AppValidators.sku,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _material,
                            decoration: const InputDecoration(
                              labelText: 'Material',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _color,
                            decoration: const InputDecoration(
                              labelText: 'Color',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _size,
                            decoration: const InputDecoration(
                              labelText: 'Size',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _weight,
                            decoration: const InputDecoration(
                              labelText: 'Weight',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _totalImages >= CloudinaryConfig.maxProductImages
                            ? 'Photo limit reached'
                            : 'Add photos '
                                  '($_totalImages/${CloudinaryConfig.maxProductImages})',
                      ),
                    ),
                    if (_uploading) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _UploadProgressBar(progress: _progress),
                    ],
                    if (_failedImages.isNotEmpty && !_uploading) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Image upload failed. Tap retry.',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _retryFailedUploads,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],
                    if (_images.isNotEmpty ||
                        _pendingImages.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _ImageStrip(
                        stored: _images,
                        pending: _pendingImages,
                        onSetPrimary: _setPrimary,
                        onReorder: _reorder,
                        onRemove: _removeImage,
                        onRemovePending: (int i) =>
                            setState(() => _pendingImages.removeAt(i)),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Visible in store'),
                      value: _isActive,
                      onChanged: (bool value) =>
                          setState(() => _isActive = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available for purchase'),
                      value: _isAvailable,
                      onChanged: (bool value) =>
                          setState(() => _isAvailable = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('New arrival'),
                      value: _isNewArrival,
                      onChanged: (bool value) =>
                          setState(() => _isNewArrival = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fast moving'),
                      value: _isFastMoving,
                      onChanged: (bool value) =>
                          setState(() => _isFastMoving = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Featured'),
                      value: _isFeatured,
                      onChanged: (bool value) =>
                          setState(() => _isFeatured = value),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        widget.product == null
                            ? 'Create product'
                            : 'Save changes',
                      ),
                    ),
                  ],
                ),
              );
            },
      ),
    );
  }
}

/// Upload progress for a batch, showing the headline bar **and** a per-image
/// row for each file, so the admin can see exactly which photo is in flight:
///
/// ```text
/// Uploading 2 of 4
/// Image 1   ✓
/// Image 2   ███████████░░ 80%
/// Image 3   Waiting
/// ```
class _UploadProgressBar extends StatelessWidget {
  const _UploadProgressBar({this.progress});

  final ImageUploadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final double value = progress?.fraction ?? 0;
    final List<ImageUploadStatus> statuses = progress?.statuses ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          progress == null
              ? 'Preparing upload…'
              : '${progress!.label}  ·  ${progress!.percentLabel}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(value: value, minHeight: 6),
        ),
        // Per-image rows. Skipped until the service reports real statuses so
        // "Preparing upload…" is not followed by a flash of empty rows.
        if (statuses.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          for (final ImageUploadStatus status in statuses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 18,
                    child: Icon(
                      _iconFor(status.state),
                      size: 14,
                      color: _colourFor(status.state),
                    ),
                  ),
                  SizedBox(
                    width: 58,
                    child: Text(
                      status.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _copyFor(status),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _colourFor(status.state),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  static IconData _iconFor(ImageUploadState state) {
    switch (state) {
      case ImageUploadState.waiting:
        return Icons.schedule_rounded;
      case ImageUploadState.uploading:
        return Icons.upload_rounded;
      case ImageUploadState.uploaded:
        return Icons.check_circle_outline_rounded;
      case ImageUploadState.failed:
        return Icons.error_outline_rounded;
    }
  }

  static Color _colourFor(ImageUploadState state) {
    switch (state) {
      case ImageUploadState.waiting:
        return AppColors.textHint;
      case ImageUploadState.uploading:
        return AppColors.burgundy;
      case ImageUploadState.uploaded:
        return AppColors.success;
      case ImageUploadState.failed:
        return AppColors.danger;
    }
  }

  static String _copyFor(ImageUploadStatus status) {
    switch (status.state) {
      case ImageUploadState.waiting:
        return 'Waiting';
      case ImageUploadState.uploading:
        return '${(status.progress * 100).round()}%';
      case ImageUploadState.uploaded:
        return 'Uploaded';
      case ImageUploadState.failed:
        return 'Failed';
    }
  }
}

/// The product's image gallery editor: stored Cloudinary images plus photos
/// still waiting to upload.
///
/// Stored images can be reordered (drag) and promoted to primary; pending ones
/// can only be removed, since they have not reached Cloudinary yet.
class _ImageStrip extends StatelessWidget {
  const _ImageStrip({
    required this.stored,
    required this.pending,
    required this.onSetPrimary,
    required this.onReorder,
    required this.onRemove,
    required this.onRemovePending,
  });

  final List<CloudinaryImage> stored;
  final List<XFile> pending;
  final void Function(int index) onSetPrimary;
  final void Function(int from, int to) onReorder;
  final void Function(int index) onRemove;
  final void Function(int index) onRemovePending;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Photos · ${stored.length} uploaded',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (stored.isEmpty)
          const Text('No photos yet. The first photo becomes the main image.'),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: stored.length,
          onReorder: onReorder,
          itemBuilder: (BuildContext context, int index) {
            final CloudinaryImage image = stored[index];
            return Padding(
              key: ValueKey<String>(
                image.publicId.isEmpty ? image.secureUrl : image.publicId,
              ),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: Icon(Icons.drag_handle, size: 20),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: AppNetworkImage.cloudinary(
                      image,
                      CloudinaryTransform.thumbnail,
                      width: 52,
                      height: 52,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Photo ${index + 1}${image.isPrimary ? ' · main' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (!image.isPrimary)
                    IconButton(
                      tooltip: 'Make main image',
                      onPressed: () => onSetPrimary(index),
                      icon: const Icon(Icons.star_outline, size: 20),
                    ),
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: () => onRemove(index),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            );
          },
        ),
        if (pending.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${pending.length} waiting to upload',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (int i = 0; i < pending.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined),
              title: Text(pending[i].name, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: 'Remove',
                onPressed: () => onRemovePending(i),
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
        ],
      ],
    );
  }
}

class AdminCategoryFormView extends StatefulWidget {
  const AdminCategoryFormView({super.key, this.category});

  final CategoryModel? category;

  @override
  State<AdminCategoryFormView> createState() => _AdminCategoryFormViewState();
}

class _AdminCategoryFormViewState extends State<AdminCategoryFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _icon;
  late final TextEditingController _sortOrder;
  XFile? _newImage;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final CategoryModel? category = widget.category;
    _name = TextEditingController(text: category?.name ?? '');
    _description = TextEditingController(text: category?.description ?? '');
    _icon = TextEditingController(text: category?.icon ?? '');
    _sortOrder = TextEditingController(
      text: category?.sortOrder.toString() ?? '0',
    );
    _active = category?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _icon.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file != null && mounted) setState(() => _newImage = file);
    } catch (error) {
      _showAdminMessage('Could not open the photo picker: $error', error: true);
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final CategoryRepository repository = Get.find<CategoryRepository>();
      final CategoryModel existing =
          widget.category ??
          CategoryModel(categoryId: '', name: '', createdAt: DateTime.now());
      CategoryModel draft = existing.copyWith(
        name: _name.text.trim(),
        description: _description.text.trim(),
        icon: _icon.text.trim(),
        sortOrder: int.parse(_sortOrder.text.trim()),
        isActive: _active,
      );

      final String categoryId;
      if (widget.category == null) {
        categoryId = await repository.create(draft);
      } else {
        categoryId = widget.category!.categoryId;
        await repository.update(categoryId, draft);
      }

      if (_newImage != null) {
        if (!Get.isRegistered<CloudinaryImageService>()) {
          throw StateError('Image service is not available.');
        }
        // Upload before the document is written, so a category is never saved
        // pointing at an image that does not exist.
        final CloudinaryImage uploaded =
            await Get.find<CloudinaryImageService>().uploadImage(
              _newImage!,
              type: CloudinaryImageService.typeCategories,
              entityId: categoryId,
            );
        draft = draft.copyWith(image: uploaded);
        await repository.update(categoryId, draft);

        // The replacement is stored, so the previous photo can be released.
        final CloudinaryImage? previous = existing.image;
        if (previous != null && !previous.isExternal) {
          await Get.find<CloudinaryImageService>().deleteImage(
            previous.publicId,
          );
        }
      }

      if (!mounted) return;
      Get.back<void>();
      _showAdminMessage('Category saved.');
    } catch (error) {
      _showAdminMessage('Could not save category: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Add category' : 'Edit category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Category name'),
              validator: (String? value) =>
                  AppValidators.name(value, field: 'Category name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _icon,
              decoration: const InputDecoration(
                labelText: 'Icon key (optional)',
                helperText: 'Used when no category photo is uploaded.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _sortOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Display order'),
              validator: AppValidators.stock,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_newImage?.name ?? 'Choose category image'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active in store'),
              value: _active,
              onChanged: (bool value) => setState(() => _active = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                widget.category == null ? 'Create category' : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminLoadError extends StatelessWidget {
  const _AdminLoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

void _showAdminMessage(String message, {bool error = false}) {
  Get.rawSnackbar(
    message: message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: error ? AppColors.danger : AppColors.darkBrown,
    margin: const EdgeInsets.all(AppSpacing.md),
    borderRadius: AppRadius.sm,
  );
}
