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
    if (user == null) return 'User';

    final Map<String, dynamic> metadata = user.userMetadata ?? {};
    final dynamic name = metadata['full_name'] ?? metadata['name'] ?? metadata['username'];

    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }

    final String email = user.email ?? '';
    if (email.isEmpty) return 'User';

    final String emailName = email.split('@').first;
    if (emailName.isEmpty) return 'User';

    return '${emailName[0].toUpperCase()}${emailName.substring(1)}';
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

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      data.sort((first, second) {
        final DateTime? firstDate = DateTime.tryParse(first['created_at']?.toString() ?? '');
        final DateTime? secondDate = DateTime.tryParse(second['created_at']?.toString() ?? '');
        final int firstTime = firstDate?.millisecondsSinceEpoch ?? 0;
        final int secondTime = secondDate?.millisecondsSinceEpoch ?? 0;
        return secondTime.compareTo(firstTime);
      });

      if (!mounted) return;

      setState(() {
        _watchlists = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mengambil data watchlist.';
      });
    }
  }

  Future<void> _openAddPage() async {
    routeTo('/add-watchlist');
  }

  Future<void> _openDetailPage(Map<String, dynamic> item) async {
    final dynamic result = await Navigator.of(context).pushNamed(
      '/detail-watchlist',
      arguments: item,
    );
    if (!mounted) return;
    if (result == true) await _loadWatchlists();
  }

  String _readText(Map<String, dynamic> item, String key, {String fallback = ''}) {
    final dynamic value = item[key];
    if (value == null || value.toString().trim().isEmpty) return fallback;
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
      default:
        return 'want_to_watch';
    }
  }

  String _statusLabel(dynamic value) {
    switch (_normalizeStatus(value)) {
      case 'watching':
        return 'Watching';
      case 'finished':
        return 'Finished';
      default:
        return 'Want to Watch';
    }
  }

  String _formatRating(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '-';
    final double? rating = double.tryParse(value.toString());
    if (rating == null) return value.toString();
    if (rating == rating.roundToDouble()) return rating.toInt().toString();
    return rating.toStringAsFixed(1);
  }

  List<Map<String, dynamic>> get _filteredWatchlists {
    return _watchlists.where((item) {
      final String title = _readText(item, 'title').toLowerCase();
      final String genre = _readText(item, 'genre').toLowerCase();
      final String status = _normalizeStatus(item['status']);
      final String keyword = _searchKeyword.trim().toLowerCase();

      final bool matchesSearch = keyword.isEmpty || title.contains(keyword);
      final bool matchesGenre = _selectedGenre == 'All' || genre.contains(_selectedGenre.toLowerCase());
      final bool matchesStatus = status == _selectedStatus;

      return matchesSearch && matchesGenre && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = _filteredWatchlists;

    return Scaffold(
      backgroundColor: const Color(0xff120708),
      resizeToAvoidBottomInset: true,
      
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
        child: FloatingActionButton(
          onPressed: _openAddPage,
          backgroundColor: const Color(0xFFFF3B3B),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 0,
          child: const Icon(Icons.add_rounded, size: 36),
        ),
      ),
      
      bottomNavigationBar: Container(
        color: const Color(0xff120708),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xff120708),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF3B3B), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.home, color: Color(0xFFFF3B3B), size: 28),
                onPressed: () {
                  routeTo('/home', navigationType: NavigationType.pushAndRemoveUntil);
                },
              ),
              IconButton(
                icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 28),
                onPressed: () {
                  routeTo('/profile');
                },
              ),
            ],
          ),
        ),
      ),
      
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWatchlists,
          color: const Color(0xFFFF3B3B),
          backgroundColor: const Color(0xff2A0A0E),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 30),
                      _buildSearchField(),
                      const SizedBox(height: 24),
                      _buildGenreFilter(),
                      const SizedBox(height: 24),
                      _buildStatusFilter(),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF3B3B)),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white))),
                )
              else if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('Your watchlist is empty', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildWatchlistCard(items[index]),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $_displayName',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'What do you want to watch today?',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: (value) {
        setState(() {
          _searchKeyword = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search movie or series',
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF3B3B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF3B3B), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGenreFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Genre',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _genres.map((genre) {
            final bool selected = genre == _selectedGenre;
            return GestureDetector(
              onTap: () => setState(() => _selectedGenre = genre),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFF3B3B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF3B3B)),
                ),
                child: Text(
                  genre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatusButton(label: 'Want to Watch', value: 'want_to_watch'),
            const SizedBox(width: 10),
            _buildStatusButton(label: 'Watching', value: 'watching'),
            const SizedBox(width: 10),
            _buildStatusButton(label: 'Finished', value: 'finished'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusButton({required String label, required String value}) {
    final bool selected = _selectedStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF3B3B) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFF3B3B)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
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
    final String statusLabel = _statusLabel(item['status']);

    return InkWell(
      onTap: () => _openDetailPage(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF3B3B)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 85,
                height: 115,
                child: posterUrl.isEmpty
                    ? Container(color: const Color(0xff2A0A0E), child: const Icon(Icons.movie, color: Colors.grey))
                    : Image.network(
                        posterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xff2A0A0E),
                          child: const Icon(Icons.movie, color: Colors.grey),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$type • $genre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    platform,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFF3B3B)),
                        ),
                        child: Text(
                          statusLabel,
                          style: const TextStyle(
                            color: Color(0xFFFF3B3B),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orangeAccent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}