import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:padma/core/constants/cloudinary_config.dart';
import 'package:padma/core/services/cloudinary_image_service.dart';
import 'package:padma/core/utils/error_handler.dart';

void main() {
  group('CloudinaryConfig | upload endpoint', () {
    test('targets the versioned image upload path', () {
      expect(
        CloudinaryConfig.uploadEndpoint('demo-cloud'),
        'https://api.cloudinary.com/v1_1/demo-cloud/image/upload',
      );
    });

    test('is empty without a cloud name, so callers fail fast', () {
      expect(CloudinaryConfig.uploadEndpoint(''), '');
    });

    test('remote deletion is declared impossible', () {
      // Guards the documented trade-off: if this is ever flipped to true, the
      // no-op delete helpers below are lying and must be reinstated against the
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

  group('CloudinaryImageService | unsigned upload', () {
    /// A tiny JPEG body. Real compression runs natively, so these tests drive
    /// [CloudinaryImageService.uploadOne] directly and bypass that step.
    Uint8List jpegBytes() => Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0]);

    XFile jpeg(String name) =>
        XFile.fromData(jpegBytes(), name: name, mimeType: 'image/jpeg');

    /// A service whose HTTP client always answers with [response], recording
    /// requests so a test can assert on exactly what was put on the wire.
    CloudinaryImageService serviceReturning(
      http.Response response, {
      List<http.BaseRequest>? sent,
      String preset = 'padma_unsigned',
    }) {
      return CloudinaryImageService(
        cloudName: 'demo-cloud',
        uploadPreset: preset,
        client: MockClient((http.Request request) async {
          sent?.add(request);
          return response;
        }),
      );
    }

    http.Response successResponse() => http.Response(
      jsonEncode(<String, dynamic>{
        'public_id': 'padma_collections/products/p1/necklace-abc',
        'secure_url': 'https://res.cloudinary.com/demo-cloud/x/necklace.jpg',
        'format': 'jpg',
        'width': 1600,
        'height': 1200,
      }),
      200,
    );

    test('POSTs to the upload endpoint carrying no credentials', () async {
      final List<http.BaseRequest> sent = <http.BaseRequest>[];
      final CloudinaryImageService service = serviceReturning(
        successResponse(),
        sent: sent,
      );

      await service.uploadOne(
        file: jpeg('necklace.jpg'),
        bytes: jpegBytes(),
        type: 'products',
        entityId: 'p1',
      );

      expect(sent, hasLength(1));
      final http.Request request = sent.single as http.Request;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        CloudinaryConfig.uploadEndpoint('demo-cloud'),
      );
      // An unsigned upload is authenticated by the preset alone; sending any
      // signing material would be rejected by Cloudinary.
      final Iterable<String> headers = request.headers.keys.map(
        (String k) => k.toLowerCase(),
      );
      expect(headers, isNot(contains('authorization')));
    });

    test('maps a successful response onto Cloudinary metadata', () async {
      final CloudinaryImageService service = serviceReturning(
        successResponse(),
      );

      final Map<String, dynamic> payload = await service.uploadOne(
        file: jpeg('necklace.jpg'),
        bytes: jpegBytes(),
        type: 'products',
        entityId: 'p1',
      );

      expect(payload['publicId'], 'padma_collections/products/p1/necklace-abc');
      expect(payload['format'], 'jpg');
      expect(payload['width'], 1600);
      expect(payload['height'], 1200);
    });

    test('refuses to upload when no preset is configured', () async {
      final CloudinaryImageService service = serviceReturning(
        successResponse(),
        preset: '',
      );
      expect(service.isConfigured, isFalse);

      await expectLater(
        service.uploadOne(
          file: jpeg('a.jpg'),
          bytes: jpegBytes(),
          type: 'products',
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.code,
            'code',
            'not-configured',
          ),
        ),
      );
    });

    test('surfaces Cloudinary error text rather than swallowing it', () async {
      final CloudinaryImageService service = serviceReturning(
        http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{'message': 'File size too large'},
          }),
          413,
        ),
      );

      await expectLater(
        service.uploadOne(
          file: jpeg('big.jpg'),
          bytes: jpegBytes(),
          type: 'products',
        ),
        throwsA(
          isA<AppException>()
              .having(
                (AppException e) => e.message,
                'message',
                contains('too large'),
              )
              .having((AppException e) => e.code, 'code', 'upload-failed'),
        ),
      );
    });

    test('includes Cloudinary failure reasons in batch results', () async {
      final CloudinaryImageService service = serviceReturning(
        http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{
              'message': 'Upload preset must be unsigned',
            },
          }),
          400,
        ),
      );

      final Directory temp = await Directory.systemTemp.createTemp(
        'cloudinary-upload-test',
      );
      try {
        final File imageFile = File('${temp.path}/necklace.jpg');
        await imageFile.writeAsBytes(jpegBytes());
        final ImageUploadResult result = await service.uploadImages(<XFile>[
          XFile(imageFile.path),
        ]);

        expect(result.failures, 1);
        expect(
          result.failureMessages,
          <String>['Upload preset must be unsigned'],
        );
      } finally {
        await temp.delete(recursive: true);
      }
    });

    test('never leaks a raw HTML error page into the admin UI', () async {
      final CloudinaryImageService service = serviceReturning(
        http.Response('<html><body>502 Bad Gateway</body></html>', 502),
      );

      await expectLater(
        service.uploadOne(
          file: jpeg('a.jpg'),
          bytes: jpegBytes(),
          type: 'products',
        ),
        throwsA(
          isA<AppException>()
              .having(
                (AppException e) => e.message,
                'message',
                isNot(contains('<html')),
              )
              .having((AppException e) => e.code, 'code', 'upload-failed'),
        ),
      );
    });
  });

  group('CloudinaryImageService | deletion is a no-op', () {
    final CloudinaryImageService service = CloudinaryImageService();

    test('deleteImage reports false instead of throwing', () async {
      expect(
        await service.deleteImage('padma_collections/products/p1/a'),
        isFalse,
      );
    });

    test('deleteProductImages reports zero', () async {
      expect(await service.deleteProductImages('p1'), 0);
    });

    test('bulk delete resolves rather than blocking the metadata write', () async {
      await expectLater(service.deleteImages(<String>['a', 'b', 'c']), completes);
    });

    test('canDeleteRemotely is false so UI can avoid implying a reclaim', () {
      expect(service.canDeleteRemotely, isFalse);
    });
  });
}