import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'package:idea_vault/models/idea.dart';
import 'package:idea_vault/services/drive/drive_client.dart';
import 'package:idea_vault/services/idea_store.dart';

/// In-memory fake standing in for the real Drive API. Overrides every
/// network-touching method so DriveIdeaStore/DriveMediaService can be
/// exercised without a real Google account or Drive.
class _FakeDriveClient extends DriveClient {
  final Map<String, Map<String, dynamic>> jsonFiles = {};
  final Map<String, List<int>> binaryFiles = {};
  int _counter = 0;
  bool quotaFull = false;

  _FakeDriveClient() : super(GoogleSignIn());

  String _nextId() => 'file-${_counter++}';

  @override
  Future<void> ensureQuota() async {
    if (quotaFull) throw const DriveStorageFullException();
  }

  @override
  Future<String> createJsonFile(String name, Map<String, dynamic> content) async {
    final id = _nextId();
    jsonFiles[id] = Map<String, dynamic>.from(content);
    return id;
  }

  @override
  Future<void> updateJsonFile(String fileId, Map<String, dynamic> content) async {
    if (!jsonFiles.containsKey(fileId)) {
      throw StateError('No such file $fileId');
    }
    jsonFiles[fileId] = Map<String, dynamic>.from(content);
  }

  @override
  Future<Map<String, dynamic>> readJsonFile(String fileId) async {
    final content = jsonFiles[fileId];
    if (content == null) throw StateError('No such file $fileId');
    return Map<String, dynamic>.from(content);
  }

  @override
  Future<List<drive.File>> listIdeaFiles() async {
    return jsonFiles.keys.map((id) => drive.File()..id = id).toList();
  }

  @override
  Future<String> uploadBytes(String name, List<int> bytes, String contentType) async {
    await ensureQuota();
    final id = _nextId();
    binaryFiles[id] = bytes;
    return id;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    jsonFiles.remove(fileId);
    binaryFiles.remove(fileId);
  }
}

void main() {
  late _FakeDriveClient drive0;
  late DriveIdeaStore store;

  setUp(() {
    drive0 = _FakeDriveClient();
    store = DriveIdeaStore(drive0);
  });

  Idea sampleIdea({String id = 'idea-1', String title = 'Coffee truck'}) => Idea(
        id: id,
        title: title,
        createdAt: DateTime(2026, 1, 1),
      );

  test('insertIdea then loadIdeas round-trips the JSON file', () async {
    final inserted = await store.insertIdea(sampleIdea());
    expect(inserted.title, 'Coffee truck');

    final loaded = await store.loadIdeas('user-1');
    expect(loaded, hasLength(1));
    expect(loaded.first.id, 'idea-1');
    expect(loaded.first.title, 'Coffee truck');
  });

  test('updateIdea persists changes and survives in the file content', () async {
    final idea = await store.insertIdea(sampleIdea());
    final favorited = idea.copyWith(isFavorite: true);
    await store.updateIdea(favorited);

    final loaded = await store.loadIdeas('user-1');
    expect(loaded.single.isFavorite, isTrue);
  });

  test('deleteIdea removes the underlying Drive file', () async {
    await store.insertIdea(sampleIdea());
    expect(await store.loadIdeas('user-1'), hasLength(1));

    await store.deleteIdea('idea-1');
    expect(await store.loadIdeas('user-1'), isEmpty);
  });

  test('writeCache then readCache round-trips a cached research payload', () async {
    await store.insertIdea(sampleIdea());
    await store.writeCache('idea-1', 'research', {'summary': 'Looks promising'});

    final cached = await store.readCache('idea-1', 'research');
    expect(cached, isA<Map>());
    expect((cached as Map)['summary'], 'Looks promising');
  });

  test('updateIdea does not clobber a previously cached research payload', () async {
    await store.insertIdea(sampleIdea());
    await store.writeCache('idea-1', 'research', {'summary': 'Cached'});

    await store.updateIdea(sampleIdea().copyWith(isFavorite: true));

    final cached = await store.readCache('idea-1', 'research');
    expect((cached as Map)['summary'], 'Cached');
  });

  test('readCache returns null for a key that was never written', () async {
    await store.insertIdea(sampleIdea());
    final cached = await store.readCache('idea-1', 'affiliates');
    expect(cached, isNull);
  });

  test('uploadBytes throws DriveStorageFullException when quota is exhausted', () async {
    drive0.quotaFull = true;
    expect(
      () => drive0.uploadBytes('idea-1-image.jpg', [1, 2, 3], 'image/jpeg'),
      throwsA(isA<DriveStorageFullException>()),
    );
  });
}
