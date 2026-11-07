import 'package:flutter_test/flutter_test.dart';
import 'package:habitsync/services/rag_service.dart';

void main() {
  test('RAG retrieves the ACID passage from built-in notes', () {
    final rag = RagService();
    final hits = rag.retrieveRelevantChunks('What are ACID properties?');
    expect(hits, isNotEmpty);
    expect(hits.any((c) => c.content.toLowerCase().contains('atomicity')), isTrue);
  });

  test('RAG indexes pasted pages with page numbers', () {
    final rag = RagService();
    final r = rag.ingestPages(
      title: 'Bio',
      domain: 'Biology',
      pages: ['Mitochondria are the powerhouse of the cell and produce ATP through respiration.', 'Ribosomes synthesize proteins from messenger RNA in the cytoplasm.'],
    );
    expect(r.document.pageCount, 2);
    final hit = rag.retrieveRelevantChunks('ribosomes proteins', docId: r.document.id);
    expect(hit.first.pageNumber, 2);
  });
}
