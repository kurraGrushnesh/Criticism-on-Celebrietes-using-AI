/// Riverpod providers for the search feature.
///
/// [searchRepositoryProvider] — singleton [SearchRepository]
/// [recentSearchesProvider] — reactive list of recent search strings
/// [searchCountProvider] — tracks total searches for sign-in prompt
///
/// Dependencies: [SearchRepository] with Hive + Firestore dual storage.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/search_repository.dart';

/// Provides the [SearchRepository] singleton.
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository();
});

/// Provides the current list of recent searches.
///
/// This is a [StateProvider] that gets manually updated after each
/// search operation to keep the UI reactive without re-reading Hive.
final recentSearchesProvider = StateProvider<List<String>>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.getRecentSearches();
});

/// Tracks the total number of searches for the Google Sign-In prompt.
///
/// After [AppConstants.searchesBeforeSignInPrompt] searches, the
/// dashboard will show a non-blocking bottom sheet.
final searchCountProvider = StateProvider<int>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.searchCount;
});

/// Provides the list of favorited celebrity slugs.
final favoritesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.getFavorites();
});
