import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rag_chunk.dart';

class CloudDocs {
  final List<StudyDocument> documents;
  final List<RagChunk> chunks;
  CloudDocs(this.documents, this.chunks);
}

/// Firestore layout:
///   users/{uid}                    -> profile, goals, trees, heatmap
///   users/{uid}/documents/{docId}  -> uploaded document metadata
///   users/{uid}/chunks/{chunkId}   -> indexed text chunks (for RAG)
class CloudService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  Future<Map<String, dynamic>?> loadState(String uid) async {
    final snap = await _user(uid).get();
    return snap.exists ? snap.data() : null;
  }

  Future<void> saveState(String uid, Map<String, dynamic> data) {
    return _user(uid).set({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> saveDocument(String uid, StudyDocument doc, List<RagChunk> chunks) async {
    final base = _user(uid);
    await base.collection('documents').doc(doc.id).set(doc.toMap());
    for (var i = 0; i < chunks.length; i += 400) {
      final batch = _db.batch();
      for (final c in chunks.skip(i).take(400)) {
        batch.set(base.collection('chunks').doc(c.id), c.toMap());
      }
      await batch.commit();
    }
  }

  Future<void> deleteDocument(String uid, String docId) async {
    final base = _user(uid);
    await base.collection('documents').doc(docId).delete();
    final q = await base.collection('chunks').where('docId', isEqualTo: docId).get();
    for (var i = 0; i < q.docs.length; i += 400) {
      final batch = _db.batch();
      for (final d in q.docs.skip(i).take(400)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<CloudDocs> loadDocuments(String uid) async {
    final base = _user(uid);
    final docSnap = await base.collection('documents').get();
    final chunkSnap = await base.collection('chunks').get();
    final docs = docSnap.docs.map((d) => StudyDocument.fromMap(d.data())).toList()
      ..sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
    final chunks = chunkSnap.docs.map((d) => RagChunk.fromMap(d.data())).toList();
    return CloudDocs(docs, chunks);
  }
}
