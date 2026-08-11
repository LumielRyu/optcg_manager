import '../models/op_card.dart';
import 'liga_variant_classifier.dart';

OpCard? bestOpCardForStoredIdentity({
  required Iterable<OpCard> variants,
  required String cardCode,
  required String storedName,
  required String storedSetName,
  String storedImageUrl = '',
}) {
  final candidates = variants.toList(growable: false);
  if (candidates.isEmpty) return null;

  final normalizedCode = cardCode.trim().toUpperCase();
  final normalizedName = normalizeOpCardIdentityText(storedName);
  final normalizedSet = normalizeOpCardIdentityText(storedSetName);
  final normalizedImage = storedImageUrl.trim();
  final requested = classifyLigaVariant(
    cardName: storedName,
    cardCode: normalizedCode,
  );
  OpCard? best;
  var bestScore = -1;

  for (final candidate in candidates) {
    final candidateCode = candidate.code.trim().toUpperCase();
    final candidateName = normalizeOpCardIdentityText(candidate.name);
    final candidateSet = normalizeOpCardIdentityText(candidate.setName);
    final candidateVariant = classifyLigaVariant(
      cardName: candidate.name,
      cardCode: candidateCode,
    );
    final compatibleVariant = ligaVariantKindsCompatible(
      requested.kind,
      candidateVariant.kind,
    );

    if (requested.requiresStrictMatch && !compatibleVariant) continue;

    var score = 0;
    if (normalizedImage.isNotEmpty &&
        candidate.image.trim() == normalizedImage) {
      score += 2400;
    }
    if (compatibleVariant) score += 1200;
    if (normalizedName.isNotEmpty && candidateName == normalizedName) {
      score += 1000;
    }
    if (normalizedSet.isNotEmpty && candidateSet == normalizedSet) {
      score += 200;
    }
    if (candidateCode == normalizedCode) score += 80;
    if (candidate.image.trim().isNotEmpty) score += 5;

    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }

  return best;
}

String resolvedStoredCardImage({
  required String cardCode,
  required String storedName,
  required String storedImageUrl,
  required OpCard? catalogCard,
}) {
  final normalizedStoredImage = storedImageUrl.trim();
  final catalogImage = catalogCard?.image.trim() ?? '';
  if (catalogImage.isEmpty) return storedImageUrl;
  if (normalizedStoredImage.isEmpty) return catalogImage;

  final requested = classifyLigaVariant(
    cardName: storedName,
    cardCode: cardCode,
  );
  if (!requested.requiresStrictMatch) return storedImageUrl;

  // Liga images are selected from the exact marketplace printing. Some
  // upstream catalog rows carry a strict variant name (for example, Full Art)
  // while their image still points to the regular printing. In that case the
  // persisted Liga image is the stronger identity signal and must not be
  // overwritten by the auxiliary catalog.
  if (_isLigaOnePieceRepositoryImage(normalizedStoredImage)) {
    return storedImageUrl;
  }

  final candidate = classifyLigaVariant(
    cardName: catalogCard!.name,
    cardCode: catalogCard.code,
  );
  return ligaVariantKindsCompatible(requested.kind, candidate.kind)
      ? catalogImage
      : storedImageUrl;
}

bool _isLigaOnePieceRepositoryImage(String imageUrl) {
  final uri = Uri.tryParse(imageUrl);
  if (uri == null) return false;
  return uri.host.toLowerCase() == 'repositorio.sbrauble.com' &&
      uri.path.toLowerCase().contains('/arquivos/in/onepiece/');
}

String normalizeOpCardIdentityText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
