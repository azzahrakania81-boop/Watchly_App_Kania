import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailWatchlistPage extends StatefulWidget {
  static RouteView path = (
    '/detail-watchlist',
    (_) => const DetailWatchlistPage(),
  );

  const DetailWatchlistPage({super.key});

  @override
  State<DetailWatchlistPage> createState() => _DetailWatchlistPageState();
}

class _DetailWatchlistPageState extends State<DetailWatchlistPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isDeleting = false;

  Map<String, dynamic>? _getItemData(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map<String, dynamic>) return routeArgs;
    if (routeArgs is Map) return Map<String, dynamic>.from(routeArgs);
    return null;
  }

  String _readText(Map<String, dynamic>? item, String key, {String fallback = ''}) {
    if (item == null) return fallback;
    final value = item[key];
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
    if (value == null || value.toString().trim().isEmpty) {
      return '0.0';
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

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFB3261E)
              : const Color(0xFF237A3B),
        ),
      );
  }

  InputDecoration _editInputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFFFFA5AA)),
      hintStyle: const TextStyle(color: Color(0xFF707070)),
      filled: true,
      fillColor: const Color(0xFF242424),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF383838)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF383838)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF3B3B), width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Future<void> _saveWatchlistData(Map<String, dynamic> item, Map<String, dynamic> data) async {
    try {
      final id = item['id'];
      
      await Supabase.instance.client
          .from('watchlists')
          .update(data)
          .eq('id', id);

      debugPrint("UPDATE BERHASIL");
      _showMessage('Perubahan berhasil disimpan!');
    } catch (e) {
      debugPrint("UPDATE GAGAL: $e");
      _showMessage('Gagal menyimpan: $e', isError: true);
    }
  }

  Future<void> _openEditSheet(Map<String, dynamic> item) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final TextEditingController titleController = TextEditingController(
      text: _readText(item, 'title'),
    );
    final TextEditingController platformController = TextEditingController(
      text: _readText(item, 'platform'),
    );
    final TextEditingController ratingController = TextEditingController(
      text: item['rating']?.toString() ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: _readText(item, 'notes'),
    );
    final TextEditingController lastWatchedController = TextEditingController(
      text: _readText(item, 'last_watched'),
    );

    String selectedType = _readText(item, 'type', fallback: 'movie').toLowerCase();
    if (selectedType != 'movie' && selectedType != 'series') {
      selectedType = 'movie';
    }

    final List<String> genresList = const [
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
    final List<String> availableGenres = List<String>.from(genresList);
    String selectedGenre = _readText(item, 'genre', fallback: 'Action');
    if (!availableGenres.contains(selectedGenre)) {
      availableGenres.add(selectedGenre);
    }

    String selectedStatus = _normalizeStatus(item['status']);

    final statuses = const [
      {'value': 'want_to_watch', 'label': 'Want to Watch'},
      {'value': 'watching', 'label': 'Watching'},
      {'value': 'finished', 'label': 'Finished'},
    ];

    final Map<String, dynamic>? updatedData = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Edit Watchlist',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: titleController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(label: 'Title', hint: 'Movie or series title'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Title wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          dropdownColor: const Color(0xFF242424),
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(label: 'Type'),
                          items: const [
                            DropdownMenuItem(value: 'movie', child: Text('Movie')),
                            DropdownMenuItem(value: 'series', child: Text('Series')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => selectedType = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedGenre,
                          dropdownColor: const Color(0xFF242424),
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(label: 'Genre'),
                          items: availableGenres.map((genre) {
                            return DropdownMenuItem<String>(value: genre, child: Text(genre));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => selectedGenre = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: platformController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(label: 'Platform', hint: 'Netflix, Disney+, Viu'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          dropdownColor: const Color(0xFF242424),
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(label: 'Status'),
                          items: statuses.map((status) {
                            return DropdownMenuItem<String>(
                              value: status['value'],
                              child: Text(status['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => selectedStatus = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ratingController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(label: 'Rating', hint: '0 - 10'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: lastWatchedController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(label: 'Last Watched', hint: 'Season 2, Episode 5'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: notesController,
                          minLines: 4,
                          maxLines: 6,
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(label: 'Personal Notes', hint: 'Write your notes...'),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState?.validate() != true) return;
                              final ratingText = ratingController.text.trim().replaceAll(',', '.');
                              final double? rating = ratingText.isEmpty ? null : double.tryParse(ratingText);

                              final newData = {
                                'title': titleController.text.trim(),
                                'type': selectedType,
                                'genre': selectedGenre,
                                'platform': platformController.text.trim().isEmpty ? null : platformController.text.trim(),
                                'status': selectedStatus,
                                'rating': rating,
                                'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                'last_watched': lastWatchedController.text.trim().isEmpty ? null : lastWatchedController.text.trim(),
                              };

                              Navigator.of(sheetContext).pop(newData);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF3B3B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (updatedData != null && mounted) {
      await _saveWatchlistData(item, updatedData);
      if (!mounted) return;
      setState(() {
        item.addAll(updatedData);
      });
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xff2A0A0E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFF3B3B)),
          ),
          title: const Text('Delete Watchlist?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin menghapus "${_readText(item, 'title', fallback: 'this watchlist')}"?', style: const TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B3B), foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteWatchlist(item);
    }
  }

  Future<void> _deleteWatchlist(Map<String, dynamic> item) async {
    final user = _supabase.auth.currentUser;
    final id = item['id'];

    if (user == null || id == null) {
      _showMessage('User atau ID watchlist tidak ditemukan.', isError: true);
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final String posterUrl = _readText(item, 'poster_url');
      await _supabase.from('watchlists').delete().eq('id', id).eq('user_id', user.id);

      final String? posterPath = _extractPosterStoragePath(posterUrl);
      if (posterPath != null) {
        try {
          await _supabase.storage.from('watchlist-posters').remove([posterPath]);
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (error) {
      _showMessage('Gagal menghapus watchlist: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String? _extractPosterStoragePath(String posterUrl) {
    if (posterUrl.isEmpty) return null;
    const marker = '/storage/v1/object/public/watchlist-posters/';
    final int markerIndex = posterUrl.indexOf(marker);
    if (markerIndex == -1) return null;
    String path = posterUrl.substring(markerIndex + marker.length);
    if (path.contains('?')) path = path.split('?').first;
    return Uri.decodeComponent(path);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? item = _getItemData(context);

    if (item == null) {
      return Scaffold(
        backgroundColor: const Color(0xff120708),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Data watchlist tidak ditemukan.', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B3B)),
                child: const Text('Kembali ke Home', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xff120708),
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
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                  },
                  child: const Center(
                    child: Icon(Icons.home_outlined, color: Colors.white, size: 28),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pushNamed('/profile');
                  },
                  child: const Center(
                    child: Icon(Icons.person_outline_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFF3B3B), width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFFFF3B3B), size: 20),
                    ),
                  ),
                  const Text(
                    'Watch Detail',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 36), // Penyeimbang agar teks berada di tengah secara presisi
                ],
              ),
              const SizedBox(height: 30),

              // Header Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF3B3B)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPoster(item),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _readText(item, 'title', fallback: 'Untitled'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_readText(item, 'type', fallback: 'Movie')} • ${_readText(item, 'genre', fallback: 'Uncategorized')}',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFF3B3B)),
                            ),
                            child: Text(
                              _statusLabel(item['status']),
                              style: const TextStyle(color: Color(0xFFFF3B3B), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: List.generate(5, (_) => const Icon(Icons.star, color: Colors.amber, size: 14)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatRating(item['rating']),
                            style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Info Tiles
              _buildInfoTile(icon: Icons.play_arrow, label: 'Platform', value: _readText(item, 'platform', fallback: '-')),
              _buildInfoTile(icon: Icons.star, label: 'Genre', value: _readText(item, 'genre', fallback: '-')),
              _buildInfoTile(icon: Icons.check, label: 'Last Watched', value: _readText(item, 'last_watched', fallback: '-')),

              const SizedBox(height: 8),

              // Personal Notes
              const Text(
                'Personal Notes',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xff2A0A0E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF3B3B)),
                ),
                child: Text(
                  _readText(item, 'notes', fallback: '...'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isDeleting ? null : () => _openEditSheet(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B3B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('EDIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isDeleting ? null : () => _confirmDelete(item),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xff120708),
                          side: const BorderSide(color: Color(0xFFFF3B3B), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _isDeleting ? 'DELETING...' : 'DELETE',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xff2A0A0E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF3B3B)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPoster(Map<String, dynamic> item) {
    final posterUrl = _readText(item, 'poster_url');

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 110,
        height: 155,
        color: const Color(0xff2A0A0E),
        child: posterUrl.isEmpty
            ? const Center(child: Icon(Icons.movie, color: Colors.grey, size: 40))
            : Image.network(
                posterUrl,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Color(0xFFFF3B3B), strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.error_outline, color: Colors.grey));
                },
              ),
      ),
    );
  }
}