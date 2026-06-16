import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EncryptionService {
  final AesGcm _algorithm = AesGcm.with256bits();
  Uint8List? _lastNonce;

  Future<SecretKey> generateKey() async {
    return _algorithm.newSecretKey();
  }

  Future<Uint8List> getLastNonce() async {
    return _lastNonce ?? Uint8List(12);
  }

  Future<Uint8List> encryptFile({
    required File inputFile,
    required SecretKey key,
    File? outputFile,
  }) async {
    final inputBytes = await inputFile.readAsBytes();
    final secretKeyBytes = await key.extractBytes();

    final result = await Isolate.run(() async {
      final algorithm = AesGcm.with256bits();
      final nonce = algorithm.newNonce();
      final secretKey = SecretKey(secretKeyBytes);

      final secretBox = await algorithm.encrypt(
        inputBytes,
        secretKey: secretKey,
        nonce: nonce,
      );

      return Uint8List.fromList([
        ...nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);
    });

    _lastNonce = result.sublist(0, 12);

    if (outputFile != null) {
      await outputFile.writeAsBytes(result);
    }
    return result;
  }

  Future<void> decryptFile({
    required File encryptedFile,
    required SecretKey key,
    File? outputFile,
  }) async {
    final encryptedBytes = await encryptedFile.readAsBytes();
    final secretKeyBytes = await key.extractBytes();

    final decrypted = await Isolate.run(() async {
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(secretKeyBytes);

      final nonce = encryptedBytes.sublist(0, 12);
      final mac = Mac(encryptedBytes.sublist(encryptedBytes.length - 16));
      final cipherText =
          encryptedBytes.sublist(12, encryptedBytes.length - 16);

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      return algorithm.decrypt(secretBox, secretKey: secretKey);
    });

    if (outputFile != null) {
      await outputFile.writeAsBytes(decrypted);
    }
  }

  Future<File> getTempDecryptFile(String originalName) async {
    final cacheDir = await getTemporaryDirectory();
    final tempPath = p.join(cacheDir.path, 'dec_$originalName');
    return File(tempPath);
  }

  Future<void> cleanTempFiles() async {
    final cacheDir = await getTemporaryDirectory();
    final files = cacheDir.listSync();
    for (final file in files) {
      if (file is File && p.basename(file.path).startsWith('dec_')) {
        await file.delete();
      }
    }
  }

  String generateEncryptedName() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
