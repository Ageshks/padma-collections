import 'package:flutter_test/flutter_test.dart';
import 'package:padma/core/constants/cloudinary_config.dart';
import 'package:padma/data/models/models.dart';

void main() {
  // The cloud name is normally pushed by AppController once settings load.
  setUp(() => CloudinaryDelivery.cloudName = 'demo-cloud');
  tearDown(() => CloudinaryDelivery.cloudName = '');

  group('CloudinaryConfig | unsigned upload contract', () {
    test('targets the versioned image upload path', () {
      expect(
        CloudinaryConfig.uploadEndpoint('demo-cloud'),
        'https://api.cloudinary.com/v1_1/demo-cloud/image/upload',
      );
    });

    test('is empty without a cloud name so callers fail fast', () {
      expect(CloudinaryConfig.uploadEndpoint(''), '');
    });

    test('remote deletion is declared impossible', () {
      // Guards the documented trade-off: if this is ever flipped to true, the
      // no-op delete helpers are lying and must be reinstated against the
      // signed Admin API.
      expect(CloudinaryConfig.canDeleteRemotely, isFalse);
    });
  });

  group('CloudinaryConfig | folders', () {
    test('nests products and categories under their entity id', () {
      expect(
        CloudinaryConfig.publicFolderFor('products', 'PC-NK-001'),
        'padma_collections/products/PC-NK-001',
      );
      expect(
        CloudinaryConfig.publicFolderFor('categories', 'cat-1'),
        'padma_collections/categories/cat-1',
      );
    });

    test('keeps banners and store assets flat', () {
      expect(
        CloudinaryConfig.publicFolderFor('banners', 'promo-1'),
        'padma_collections/banners',
      );
      expect(
        CloudinaryConfig.publicFolderFor('store', null),
        'padma_collections/store',
      );
    });

    test('sanitises a hostile entity id so it cannot escape its folder', () {
      final String folder = CloudinaryConfig.publicFolderFor(
        'products',
        '../../evil folder',
      );
      expect(folder, startsWith('padma_collections/products/'));
      expect(folder, isNot(contains('..')));
      expect(folder, isNot(contains(' ')));
    });

    test('falls back to the root folder for an unknown type', () {
      expect(CloudinaryConfig.folderFor('nonsense'), 'padma_collections');
    });
  });

  group('CloudinaryDelivery | URL construction', () {
    test('builds a delivery URL with the transformation in the path', () {
      expect(
        CloudinaryDelivery.build(
          'padma_collections/products/p1/necklace',
          CloudinaryTransform.productCard,
          format: 'jpg',
        ),
        'https://res.cloudinary.com/demo-cloud/image/upload/'
        'c_fill,w_500,h_500,q_auto,f_auto/'
        'padma_collections/products/p1/necklace.jpg',
      );
    });

    test('always requests HTTPS', () {
      for (final CloudinaryTransform t in CloudinaryTransform.values) {
        expect(
          CloudinaryDelivery.build('p/abc', t).startsWith('https://'),
          isTrue,
          reason: '$t must be served over HTTPS',
        );
      }
    });

    test('each transformation requests its own size', () {
      String urlFor(CloudinaryTransform t) =>
          CloudinaryDelivery.build('p/abc', t, format: 'jpg');

      expect(urlFor(CloudinaryTransform.thumbnail), contains('w_200,h_200'));
      expect(urlFor(CloudinaryTransform.productCard), contains('w_500,h_500'));
      expect(
        urlFor(CloudinaryTransform.productDetail),
        contains('w_1200,h_1200'),
      );
      expect(urlFor(CloudinaryTransform.banner), contains('w_1600,h_700'));
      expect(urlFor(CloudinaryTransform.category), contains('w_500,h_500'));
    });

    test('every transformation negotiates format automatically', () {
      // f_auto is what gives customers AVIF/WebP where supported.
      for (final CloudinaryTransform t in CloudinaryTransform.values) {
        expect(t.segment, contains('f_auto'), reason: '$t must use f_auto');
      }
    });

    test('returns an empty string when no cloud name is configured', () {
      CloudinaryDelivery.cloudName = '';
      // An empty URL renders the "no image" placeholder rather than requesting
      // a malformed address.
      expect(
        CloudinaryDelivery.build('p/abc', CloudinaryTransform.productCard),
        '',
      );
    });

    test('an explicit cloud name overrides the app-wide one', () {
      expect(
        CloudinaryDelivery.build(
          'p/abc',
          CloudinaryTransform.thumbnail,
          cloudName: 'other-cloud',
        ),
        startsWith('https://res.cloudinary.com/other-cloud/'),
      );
    });
  });

  group('CloudinaryImage | delivery URLs', () {
    test('builds a URL for each transformation from one public id', () {
      const CloudinaryImage image = CloudinaryImage(
        publicId: 'padma_collections/products/p1/necklace',
        format: 'jpg',
      );

      expect(
        image.urlFor(CloudinaryTransform.thumbnail),
        endsWith('padma_collections/products/p1/necklace.jpg'),
      );
      expect(
        image.urlFor(CloudinaryTransform.productDetail),
        contains('c_fill,w_1200,h_1200'),
      );
    });

    test('one stored id serves every size without extra storage', () {
      const CloudinaryImage image = CloudinaryImage(
        publicId: 'p/abc',
        format: 'jpg',
      );

      final Set<String> urls = <String>{
        for (final CloudinaryTransform t in CloudinaryTransform.values)
          image.urlFor(t),
      };

      // Every distinct size resolves from the one stored public id. Fewer URLs
      // than transforms is correct: `category` and `product_card` are both
      // 500x500 and therefore share a segment.
      expect(urls.length, lessThanOrEqualTo(CloudinaryTransform.values.length));
      expect(urls.length, greaterThanOrEqualTo(4));
      expect(
        urls.every((String u) => u.contains('padma_collections')),
        isFalse,
      );
      expect(urls.every((String u) => u.endsWith('/p/abc.jpg')), isTrue);
    });

    test('falls back to the stored original when no cloud name is set', () {
      CloudinaryDelivery.cloudName = '';
      const CloudinaryImage image = CloudinaryImage(
        publicId: 'p/abc',
        secureUrl: 'https://res.cloudinary.com/demo/image/upload/p/abc.jpg',
      );

      expect(image.urlFor(CloudinaryTransform.thumbnail), image.secureUrl);
    });

    test('an external URL is returned unchanged for every transformation', () {
      const CloudinaryImage image = CloudinaryImage(
        publicId: '',
        secureUrl: 'https://images.unsplash.com/photo-123?w=800',
      );

      expect(image.isExternal, isTrue);
      expect(
        image.urlFor(CloudinaryTransform.productDetail),
        'https://images.unsplash.com/photo-123?w=800',
      );
    });
  });

  group('CloudinaryImage | Firestore mapping', () {
    test('reads the metadata the admin app writes', () {
      final List<CloudinaryImage> images = CloudinaryImage.listFrom(<Object>[
        <String, dynamic>{
          'publicId': 'padma_collections/products/p1/a',
          'secureUrl': 'https://res.cloudinary.com/demo/image/upload/p1/a.jpg',
          'resourceType': 'image',
          'format': 'jpg',
          'width': 1600,
          'height': 1600,
          'isPrimary': true,
          'sortOrder': 0,
        },
        <String, dynamic>{
          'publicId': 'padma_collections/products/p1/b',
          'isPrimary': false,
          'sortOrder': 1,
        },
      ]);

      expect(images, hasLength(2));
      expect(images.first.publicId, 'padma_collections/products/p1/a');
      expect(images.first.format, 'jpg');
      expect(images.first.width, 1600);
      expect(images.first.isPrimary, isTrue);
      expect(images.first.isExternal, isFalse);
    });

    test('reads legacy bare-URL arrays', () {
      // Documents written before any migration stored ["https://…"].
      final List<CloudinaryImage> images = CloudinaryImage.listFrom(<Object>[
        'https://images.unsplash.com/a.jpg',
        'https://images.unsplash.com/b.jpg',
      ]);

      expect(images, hasLength(2));
      expect(images.every((CloudinaryImage i) => i.isExternal), isTrue);
      expect(images.first.isPrimary, isTrue);
      expect(images[1].isPrimary, isFalse);
    });

    test('round-trips through toMap without losing metadata', () {
      final CloudinaryImage original = CloudinaryImage(
        publicId: 'padma_collections/products/p1/a',
        secureUrl: 'https://res.cloudinary.com/demo/image/upload/p1/a.jpg',
        resourceType: 'image',
        format: 'png',
        width: 1200,
        height: 1600,
        isPrimary: true,
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      );

      final CloudinaryImage copy = CloudinaryImage.fromMap(original.toMap());

      expect(copy.publicId, original.publicId);
      expect(copy.secureUrl, original.secureUrl);
      expect(copy.format, 'png');
      expect(copy.width, 1200);
      expect(copy.height, 1600);
      expect(copy.isPrimary, isTrue);
    });

    test('drops entries that carry no image at all', () {
      final List<CloudinaryImage> images = CloudinaryImage.listFrom(<Object?>[
        '',
        null,
        'https://images.unsplash.com/keep.jpg',
      ]);

      expect(images, hasLength(1));
    });
  });

  group('CloudinaryImage | ordering guarantees', () {
    test('normalised renumbers sortOrder and keeps exactly one primary', () {
      final List<CloudinaryImage> result =
          CloudinaryImage.normalised(<CloudinaryImage>[
            const CloudinaryImage(publicId: 'a', sortOrder: 5),
            const CloudinaryImage(publicId: 'b', sortOrder: 2, isPrimary: true),
            const CloudinaryImage(publicId: 'c', sortOrder: 9),
          ]);

      expect(result.map((CloudinaryImage i) => i.publicId).toList(), <String>[
        'b',
        'a',
        'c',
      ]);
      expect(result.map((CloudinaryImage i) => i.sortOrder).toList(), <int>[
        0,
        1,
        2,
      ]);
      expect(result.where((CloudinaryImage i) => i.isPrimary), hasLength(1));
      expect(result.first.isPrimary, isTrue);
    });

    test('normalised promotes the first image when none is primary', () {
      final List<CloudinaryImage> result =
          CloudinaryImage.normalised(<CloudinaryImage>[
            const CloudinaryImage(publicId: 'a', sortOrder: 0),
            const CloudinaryImage(publicId: 'b', sortOrder: 1),
          ]);

      expect(result.first.isPrimary, isTrue);
      expect(result.last.isPrimary, isFalse);
    });

    test('withPrimary promotes one image and demotes the previous', () {
      final List<CloudinaryImage> result =
          CloudinaryImage.withPrimary(<CloudinaryImage>[
            const CloudinaryImage(publicId: 'a', isPrimary: true, sortOrder: 0),
            const CloudinaryImage(publicId: 'b', sortOrder: 1),
          ], 1);

      expect(result[0].isPrimary, isFalse);
      expect(result[1].isPrimary, isTrue);
    });

    test('reordered moves an image and keeps sortOrder contiguous', () {
      final List<CloudinaryImage> result = CloudinaryImage.reordered(
        <CloudinaryImage>[
          const CloudinaryImage(publicId: 'a', isPrimary: true, sortOrder: 0),
          const CloudinaryImage(publicId: 'b', sortOrder: 1),
          const CloudinaryImage(publicId: 'c', sortOrder: 2),
        ],
        2,
        0,
      );

      expect(result.map((CloudinaryImage i) => i.publicId).toList(), <String>[
        'c',
        'a',
        'b',
      ]);
      expect(result.map((CloudinaryImage i) => i.sortOrder).toList(), <int>[
        0,
        1,
        2,
      ]);
      // Reordering must not silently change which image is the main one.
      expect(result.map((CloudinaryImage i) => i.isPrimary).toList(), <bool>[
        false,
        true,
        false,
      ]);
    });

    test('reordered ignores an out-of-range index', () {
      final List<CloudinaryImage> images = <CloudinaryImage>[
        const CloudinaryImage(publicId: 'a', sortOrder: 0),
      ];

      expect(CloudinaryImage.reordered(images, 5, 0), images);
    });
  });

  group('ProductModel | images', () {
    test('primaryImageRef returns the flagged primary, not just the first', () {
      final ProductModel product = ProductModel.fromMap(<String, dynamic>{
        'productId': 'p1',
        'name': 'Necklace',
        'images': <Map<String, dynamic>>[
          <String, dynamic>{
            'publicId': 'a',
            'isPrimary': false,
            'sortOrder': 0,
          },
          <String, dynamic>{'publicId': 'b', 'isPrimary': true, 'sortOrder': 1},
        ],
      });

      expect(product.primaryImageRef?.publicId, 'b');
      expect(product.primaryImage(), contains('/b'));
      expect(product.primaryImage(), contains('c_fill,w_500,h_500'));
    });

    test('primaryImage defaults to the product_card transformation', () {
      // Cards must never pull the 1200px detail image.
      final ProductModel product = ProductModel.fromMap(<String, dynamic>{
        'productId': 'p1',
        'name': 'Necklace',
        'images': <Map<String, dynamic>>[
          <String, dynamic>{'publicId': 'a', 'isPrimary': true},
        ],
      });

      expect(product.primaryImage(), contains('w_500,h_500'));
      expect(
        product.primaryImage(variant: CloudinaryTransform.thumbnail),
        contains('w_200,h_200'),
      );
    });

    test('imageUrls returns the gallery at the requested size', () {
      final ProductModel product = ProductModel.fromMap(<String, dynamic>{
        'productId': 'p1',
        'name': 'Necklace',
        'images': <Map<String, dynamic>>[
          <String, dynamic>{'publicId': 'a', 'isPrimary': true, 'sortOrder': 0},
          <String, dynamic>{'publicId': 'b', 'sortOrder': 1},
        ],
      });

      final List<String> urls = product.imageUrls();

      expect(urls, hasLength(2));
      expect(urls.first, contains('w_1200,h_1200'));
      expect(urls.last, contains('w_1200,h_1200'));
    });

    test('imageIds lists only real Cloudinary public ids', () {
      final ProductModel product = ProductModel.fromMap(<String, dynamic>{
        'productId': 'p1',
        'name': 'Necklace',
        'images': <Object>[
          'https://images.unsplash.com/legacy.jpg',
          <String, dynamic>{'publicId': 'real-id', 'sortOrder': 1},
        ],
      });

      expect(product.imageIds, <String>['real-id']);
    });

    test('a product with no images yields an empty URL, not a crash', () {
      final ProductModel product = ProductModel.fromMap(<String, dynamic>{
        'productId': 'p1',
        'name': 'Necklace',
      });

      expect(product.hasImages, isFalse);
      expect(product.primaryImage(), '');
      expect(product.imageUrls(), isEmpty);
      expect(product.primaryImageRef, isNull);
    });

    test('toMap writes image metadata, never image bytes', () {
      final ProductModel product = ProductModel(
        productId: 'p1',
        name: 'Necklace',
        images: const <CloudinaryImage>[
          CloudinaryImage(publicId: 'a', isPrimary: true),
        ],
        createdAt: DateTime(2026, 1, 1),
      );

      final List<dynamic> images = product.toMap()['images'] as List<dynamic>;
      final Map<String, dynamic> entry = (images.first as Map)
          .cast<String, dynamic>();

      expect(entry['publicId'], 'a');
      expect(entry['isPrimary'], isTrue);
      expect(entry.containsKey('sortOrder'), isTrue);
    });

    test('normalised enforces one primary and contiguous order on save', () {
      final ProductModel product = ProductModel(
        productId: 'p1',
        name: 'Necklace',
        images: const <CloudinaryImage>[
          CloudinaryImage(publicId: 'a', sortOrder: 3),
          CloudinaryImage(publicId: 'b', sortOrder: 1),
        ],
        createdAt: DateTime(2026, 1, 1),
      ).normalised();

      expect(
        product.images.map((CloudinaryImage i) => i.publicId).toList(),
        <String>['b', 'a'],
      );
      expect(
        product.images.where((CloudinaryImage i) => i.isPrimary),
        hasLength(1),
      );
    });
  });

  group('CategoryModel | images', () {
    test('reads the nested Cloudinary image object', () {
      final CategoryModel category = CategoryModel.fromMap(<String, dynamic>{
        'categoryId': 'c1',
        'name': 'Necklaces',
        'image': <String, dynamic>{'publicId': 'cat-1'},
      });

      expect(category.hasImage, isTrue);
      expect(category.imageUrl(), contains('w_500,h_500'));
    });

    test('reads a legacy bare URL', () {
      final CategoryModel category = CategoryModel.fromMap(<String, dynamic>{
        'categoryId': 'c1',
        'name': 'Necklaces',
        'image': 'https://images.unsplash.com/legacy.jpg',
      });

      expect(category.hasImage, isTrue);
      expect(category.imageUrl(), 'https://images.unsplash.com/legacy.jpg');
    });

    test('a category with no photo reports no image', () {
      final CategoryModel category = CategoryModel.fromMap(<String, dynamic>{
        'categoryId': 'c1',
        'name': 'Necklaces',
        'icon': 'diamond',
      });

      expect(category.hasImage, isFalse);
      expect(category.imageUrl(), '');
    });
  });

  group('BannerModel | images', () {
    test('stores the public id and serves the banner transformation', () {
      final BannerModel banner = BannerModel.fromMap(<String, dynamic>{
        'bannerId': 'b1',
        'title': 'Festive sale',
        'image': <String, dynamic>{'publicId': 'ban-1'},
      });

      expect(banner.hasImage, isTrue);
      expect(banner.imageUrl(), contains('w_1600,h_700'));
    });

    test('falls back to the branded gradient when there is no image', () {
      final BannerModel banner = BannerModel.fromMap(<String, dynamic>{
        'bannerId': 'b1',
        'title': 'Festive sale',
      });

      expect(banner.hasImage, isFalse);
      expect(banner.imageUrl(), '');
    });
  });

  group('AppSettings | logo and cloud name', () {
    test('reads the Cloudinary logo and the cloud name', () {
      final AppSettings settings = AppSettings.fromMap(<String, dynamic>{
        'storeName': 'Padma Collections',
        'logoImage': <String, dynamic>{'publicId': 'logo-1'},
        'cloudinaryCloudName': 'demo-cloud',
      });

      expect(settings.cloudinaryCloudName, 'demo-cloud');
      expect(settings.logoUrl, contains('demo-cloud'));
      expect(settings.logoUrl, contains('logo-1'));
    });

    test('reads a legacy logoUrl string', () {
      final AppSettings settings = AppSettings.fromMap(<String, dynamic>{
        'storeName': 'Padma Collections',
        'logoUrl': 'https://example.com/logo.png',
      });

      expect(settings.logoUrl, 'https://example.com/logo.png');
    });

    test('has no logo when none is configured', () {
      const AppSettings settings = AppSettings();

      expect(settings.logoUrl, isNull);
      expect(settings.cloudinaryCloudName, isEmpty);
    });
  });

  group('CloudinaryConfig | upload limits', () {
    test('accepts the documented formats only', () {
      expect(CloudinaryConfig.isSupportedExtension('a.jpg'), isTrue);
      expect(CloudinaryConfig.isSupportedExtension('a.JPEG'), isTrue);
      expect(CloudinaryConfig.isSupportedExtension('a.png'), isTrue);
      expect(CloudinaryConfig.isSupportedExtension('a.webp'), isTrue);

      expect(CloudinaryConfig.isSupportedExtension('a.gif'), isFalse);
      expect(CloudinaryConfig.isSupportedExtension('a.pdf'), isFalse);
      expect(CloudinaryConfig.isSupportedExtension('a'), isFalse);
    });

    test('maps an extension to its MIME type', () {
      expect(CloudinaryConfig.contentTypeFor('a.jpg'), 'image/jpeg');
      expect(CloudinaryConfig.contentTypeFor('a.png'), 'image/png');
      expect(CloudinaryConfig.contentTypeFor('a.webp'), 'image/webp');
    });

    test('allows between 5 and 8 images per product', () {
      expect(CloudinaryConfig.maxProductImages, inInclusiveRange(5, 8));
    });
  });
}
