import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  static RouteView path = ('/home', (_) => const HomePage());

  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _watchlists = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchKeyword = '';
  String _selectedGenre = 'All';
  String _selectedStatus = 'want_to_watch';

  final List<String> _genres = const [
    'All',
    'Action',
    'Comedy',
    'Romance',
    'Horror',
    'Drama',
    'Sci-Fi',
    'Fantasy',
    'Anime',
    'Thriller',
    'Documentary',
  ];

  @override
  void initState() {
    super.initState();
    _loadWatchlists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String get _displayName {
    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      return 'User';
    }

    final Map<String, dynamic> metadata = user.userMetadata ?? {};

    final dynamic name =
        metadata['full_name'] ?? metadata['name'] ?? metadata['username'];

    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }

    final String email = user.email ?? '';

    if (email.isEmpty) {
      return 'User';
    }

    final String emailName = email.split('@').first;

    if (emailName.isEmpty) {
      return 'User';
    }

    return '${emailName[0].toUpperCase()}'
        '${emailName.substring(1)}';
  }

  Future<void> _loadWatchlists() async {
    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Sesi login tidak ditemukan. Silakan login kembali.';
      });

      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final List<Map<String, dynamic>> response = await _supabase
          .from('watchlists')
          .select()
          .eq('user_id', user.id);

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        response,
      );

      data.sort((first, second) {
        final DateTime? firstDate = DateTime.tryParse(
          first['created_at']?.toString() ?? '',
        );

        final DateTime? secondDate = DateTime.tryParse(
          second['created_at']?.toString() ?? '',
        );

        final int firstTime = firstDate?.millisecondsSinceEpoch ?? 0;

        final int secondTime = secondDate?.millisecondsSinceEpoch ?? 0;

        return secondTime.compareTo(firstTime);
      });

      if (!mounted) return;

      setState(() {
        _watchlists = data;
        _isLoading = false;
      });

      debugPrint('Current user: ${user.id}');
      debugPrint('Watchlist data: $data');
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = '${error.message}\nKode: ${error.code}';
      });

      debugPrint('Supabase error: ${error.code} - ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mengambil data watchlist: $error';
      });

      debugPrint('Home Page error: $error');
      debugPrint('$stackTrace');
    }
  }

  void _handleBack() {
    final NavigatorState navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      '/login',
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _openAddPage() async {
    final dynamic result = await Navigator.of(
      context,
    ).pushNamed('/add-watchlist');

    if (!mounted) return;

    if (result == true) {
      await _loadWatchlists();
    }
  }

  Future<void> _openDetailPage(Map<String, dynamic> item) async {
    final dynamic result = await Navigator.of(
      context,
    ).pushNamed('/detail-watchlist', arguments: item);

    if (!mounted) return;

    if (result == true) {
      await _loadWatchlists();
    }
  }

  String _readText(
    Map<String, dynamic> item,
    String key, {
    String fallback = '',
  }) {
    final dynamic value = item[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString().trim();
  }

  String _normalizeStatus(dynamic value) {
    String status = value?.toString().trim().toLowerCase() ?? '';

    status = status.replaceAll(RegExp(r'[\s-]+'), '_');

    switch (status) {
      case 'watching':
        return 'watching';

      case 'finished':
      case 'finish':
      case 'completed':
        return 'finished';

      case 'want_to_watch':
      case 'wanttowatch':
      case 'wishlist':
      case '':
        return 'want_to_watch';

      default:
        return status;
    }
  }

  String _statusLabel(dynamic value) {
    switch (_normalizeStatus(value)) {
      case 'watching':
        return 'WATCHING';

      case 'finished':
        return 'FINISHED';

      default:
        return 'WANT TO WATCH';
    }
  }

  String _formatRating(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    final double? rating = double.tryParse(value.toString());

    if (rating == null) {
      return value.toString();
    }

    if (rating == rating.roundToDouble()) {
      return rating.toInt().toString();
    }

    return rating.toStringAsFixed(1);
  }

  List<Map<String, dynamic>> get _filteredWatchlists {
    return _watchlists.where((item) {
      final String title = _readText(item, 'title').toLowerCase();

      final String genre = _readText(item, 'genre').toLowerCase();

      final String status = _normalizeStatus(item['status']);

      final String keyword = _searchKeyword.trim().toLowerCase();

      final bool matchesSearch = keyword.isEmpty || title.contains(keyword);

      final bool matchesGenre =
          _selectedGenre == 'All' ||
          genre.contains(_selectedGenre.toLowerCase());

      final bool matchesStatus = status == _selectedStatus;

      return matchesSearch && matchesGenre && matchesStatus;
    }).toList();
  }

  void _handleBottomNavigation(int index) {
    switch (index) {
      case 0:
        break;

      case 1:
        _searchFocusNode.requestFocus();
        break;

      case 2:
        _openAddPage();
        break;

      case 3:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Halaman Profile belum dibuat.')),
          );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = _filteredWatchlists;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      resizeToAvoidBottomInset: true,

      floatingActionButton: FloatingActionButton(
        onPressed: _openAddPage,
        backgroundColor: const Color(0xFFE50914),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: _handleBottomNavigation,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF171717),
        selectedItemColor: const Color(0xFFFF747B),
        unselectedItemColor: const Color(0xFF999999),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline_rounded),
            label: 'Add',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWatchlists,
          color: const Color(0xFFE50914),
          backgroundColor: const Color(0xFF242424),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 26),
                      _buildGreeting(),
                      const SizedBox(height: 26),
                      _buildSearchField(),
                      const SizedBox(height: 18),
                      _buildGenreFilter(),
                      const SizedBox(height: 18),
                      _buildStatusFilter(),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final Map<String, dynamic> item = items[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildWatchlistCard(item),
                      );
                    }, childCount: items.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: _handleBack,
          tooltip: 'Back',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),

        const SizedBox(width: 7),

        const Text(
          'Watchly',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $_displayName!',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your cinematic journey continues.',
            style: TextStyle(color: Color(0xFFBEBEBE), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (value) {
          setState(() {
            _searchKeyword = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search movie titles...',
          hintStyle: const TextStyle(color: Color(0xFF777777)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFFFA6AC),
          ),
          suffixIcon: _searchKeyword.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchKeyword = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFA0A0A0),
                  ),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF292929),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE50914)),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreFilter() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _genres.length,
          separatorBuilder: (_, __) {
            return const SizedBox(width: 9);
          },
          itemBuilder: (context, index) {
            final String genre = _genres[index];

            final bool selected = genre == _selectedGenre;

            return ChoiceChip(
              selected: selected,
              showCheckmark: false,
              side: BorderSide.none,
              backgroundColor: const Color(0xFF292929),
              selectedColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              label: Text(genre),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFFE4BDBF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedGenre = genre;
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            _buildStatusButton(label: 'Want to Watch', value: 'want_to_watch'),
            _buildStatusButton(label: 'Watching', value: 'watching'),
            _buildStatusButton(label: 'Finished', value: 'finished'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton({required String label, required String value}) {
    final bool selected = _selectedStatus == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatus = value;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF303030) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF777777),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatchlistCard(Map<String, dynamic> item) {
    final String title = _readText(item, 'title', fallback: 'Untitled');

    final String type = _readText(item, 'type', fallback: 'Movie');

    final String genre = _readText(item, 'genre', fallback: 'Uncategorized');

    final String platform = _readText(item, 'platform');

    final String posterUrl = _readText(item, 'poster_url');

    final String rating = _formatRating(item['rating']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetailPage(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 166,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF282828)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 94,
                  height: 146,
                  child: posterUrl.isEmpty
                      ? _buildPosterPlaceholder()
                      : Image.network(
                          posterUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return Container(
                              color: const Color(0xFF292929),
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFE50914),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPosterPlaceholder();
                          },
                        ),
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFE50914),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          _buildTag(genre),
                          if (platform.isNotEmpty) _buildTag(platform),
                        ],
                      ),

                      const Spacer(),

                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB800),
                            size: 19,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _buildStatusBadge(item['status']),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 5),

              const Center(
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF999999),
                  size: 25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFD1D1D1), fontSize: 9),
      ),
    );
  }

  Widget _buildStatusBadge(dynamic status) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF321013),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFE74A52),
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      color: const Color(0xFF292929),
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_outlined,
        color: Color(0xFF777777),
        size: 40,
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isFiltering =
        _searchKeyword.trim().isNotEmpty ||
        _selectedGenre != 'All' ||
        _selectedStatus != 'want_to_watch';

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 30, 30, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              isFiltering ? 'No matching watchlist' : 'Your watchlist is empty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltering
                  ? 'Try changing the search, genre, or status filter.'
                  : 'Add your first movie or series.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (!isFiltering)
              ElevatedButton.icon(
                onPressed: _openAddPage,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Watchlist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 30, 30, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 60,
            ),
            const SizedBox(height: 15),
            const Text(
              'Failed to load watchlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadWatchlists,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
