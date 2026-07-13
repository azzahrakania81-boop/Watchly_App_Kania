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

  Map<String, dynamic>? _item;

  bool _argumentsLoaded = false;
  bool _isDeleting = false;

  final List<String> _genres = const [
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

  final List<Map<String, String>> _statuses = const [
    {'value': 'want_to_watch', 'label': 'Want to Watch'},
    {'value': 'watching', 'label': 'Watching'},
    {'value': 'finished', 'label': 'Finished'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argumentsLoaded) return;

    _argumentsLoaded = true;

    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is Map<String, dynamic>) {
      _item = Map<String, dynamic>.from(arguments);
    } else if (arguments is Map) {
      _item = Map<String, dynamic>.from(arguments);
    }
  }

  String _readText(String key, {String fallback = ''}) {
    final value = _item?[key];

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
        return 'WATCHING';

      case 'finished':
        return 'FINISHED';

      default:
        return 'WANT TO WATCH';
    }
  }

  String _formatRating(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Not rated';
    }

    final double? rating = double.tryParse(value.toString());

    if (rating == null) {
      return value.toString();
    }

    if (rating == rating.roundToDouble()) {
      return '${rating.toInt()}/10';
    }

    return '${rating.toStringAsFixed(1)}/10';
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
        borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.3),
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

  // --- Fungsi Baru: Menyimpan data di latar belakang ---
 Future<void> _saveWatchlistData(Map<String, dynamic> data) async {
  try {
    final id = _item!['id'];

    debugPrint("ID UPDATE: $id");
    debugPrint("DATA UPDATE: $data");

    await Supabase.instance.client
        .from('watchlists')
        .update(data)
        .eq('id', id);

    debugPrint("UPDATE SUCCESS");

  } catch (e) {
    debugPrint("UPDATE FAILED: $e");
  }
}
  Future<void> _openEditSheet() async {
    if (_item == null) return;

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final TextEditingController titleController = TextEditingController(
      text: _readText('title'),
    );

    final TextEditingController platformController = TextEditingController(
      text: _readText('platform'),
    );

    final TextEditingController ratingController = TextEditingController(
      text: _item?['rating']?.toString() ?? '',
    );

    final TextEditingController notesController = TextEditingController(
      text: _readText('notes'),
    );

    final TextEditingController lastWatchedController = TextEditingController(
      text: _readText('last_watched'),
    );

    String selectedType = _readText('type', fallback: 'movie').toLowerCase();

    if (selectedType != 'movie' && selectedType != 'series') {
      selectedType = 'movie';
    }

    final List<String> availableGenres = List<String>.from(_genres);

    String selectedGenre = _readText('genre', fallback: 'Action');

    if (!availableGenres.contains(selectedGenre)) {
      availableGenres.add(selectedGenre);
    }

    String selectedStatus = _normalizeStatus(_item?['status']);

    final Map<String, dynamic>?
    updatedData = await showModalBottomSheet<Map<String, dynamic>>(
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
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                              },
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
                          decoration: _editInputDecoration(
                            label: 'Title',
                            hint: 'Movie or series title',
                          ),
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
                            DropdownMenuItem(
                              value: 'movie',
                              child: Text('Movie'),
                            ),
                            DropdownMenuItem(
                              value: 'series',
                              child: Text('Series'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() {
                                selectedType = value;
                              });
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
                            return DropdownMenuItem<String>(
                              value: genre,
                              child: Text(genre),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() {
                                selectedGenre = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: platformController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(
                            label: 'Platform',
                            hint: 'Netflix, Disney+, Viu',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          dropdownColor: const Color(0xFF242424),
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(label: 'Status'),
                          items: _statuses.map((status) {
                            return DropdownMenuItem<String>(
                              value: status['value'],
                              child: Text(status['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() {
                                selectedStatus = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ratingController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(
                            label: 'Rating',
                            hint: '0 - 10',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final rating = double.tryParse(
                              value.trim().replaceAll(',', '.'),
                            );
                            if (rating == null) {
                              return 'Rating harus berupa angka';
                            }
                            if (rating < 0 || rating > 10) {
                              return 'Rating harus antara 0 sampai 10';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: lastWatchedController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(
                            label: 'Last Watched',
                            hint: 'Season 2, Episode 5',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: notesController,
                          minLines: 4,
                          maxLines: 6,
                          style: const TextStyle(color: Colors.white),
                          decoration: _editInputDecoration(
                            label: 'Personal Notes',
                            hint: 'Write your notes...',
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState?.validate() != true) {
                                return;
                              }

                              final ratingText = ratingController.text
                                  .trim()
                                  .replaceAll(',', '.');
                              final double? rating = ratingText.isEmpty
                                  ? null
                                  : double.tryParse(ratingText);

                              // Kumpulkan data dan langsung tutup modal
                              final newData = {
                                'title': titleController.text.trim(),
                                'type': selectedType,
                                'genre': selectedGenre,
                                'platform':
                                    platformController.text.trim().isEmpty
                                    ? null
                                    : platformController.text.trim(),
                                'status': selectedStatus,
                                'rating': rating,
                                'notes': notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                                'last_watched':
                                    lastWatchedController.text.trim().isEmpty
                                    ? null
                                    : lastWatchedController.text.trim(),
                              };

                              Navigator.of(sheetContext).pop(newData);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
      await _saveWatchlistData(updatedData);

      if (!mounted) return;

      setState(() {
        _item = {if (_item != null) ..._item!, ...updatedData};
      });
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF202020),
          title: const Text(
            'Delete Watchlist?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus '
            '"${_readText('title', fallback: 'this watchlist')}"?',
            style: const TextStyle(color: Color(0xFFCCCCCC)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteWatchlist();
    }
  }

  Future<void> _deleteWatchlist() async {
    final user = _supabase.auth.currentUser;
    final id = _item?['id'];

    if (user == null || id == null) {
      _showMessage('User atau ID watchlist tidak ditemukan.', isError: true);
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      final String posterUrl = _readText('poster_url');

      await _supabase
          .from('watchlists')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      final String? posterPath = _extractPosterStoragePath(posterUrl);

      if (posterPath != null) {
        try {
          await _supabase.storage.from('watchlist-posters').remove([
            posterPath,
          ]);
        } catch (error) {
          debugPrint('Poster cleanup gagal: $error');
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      _showMessage(
        'Gagal menghapus watchlist: ${error.message}',
        isError: true,
      );
    } catch (error) {
      _showMessage('Gagal menghapus watchlist: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  String? _extractPosterStoragePath(String posterUrl) {
    if (posterUrl.isEmpty) return null;

    const marker = '/storage/v1/object/public/watchlist-posters/';
    final int markerIndex = posterUrl.indexOf(marker);

    if (markerIndex == -1) return null;

    String path = posterUrl.substring(markerIndex + marker.length);
    if (path.contains('?')) {
      path = path.split('?').first;
    }

    return Uri.decodeComponent(path);
  }

  @override
  Widget build(BuildContext context) {
    if (!_argumentsLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }

    if (_item == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D0D),
          foregroundColor: Colors.white,
          leadingWidth: 70,
          leading: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Back',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          title: const Text('Watchlist Detail'),
        ),
        body: const Center(
          child: Text(
            'Data watchlist tidak ditemukan.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 70,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Back',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        title: const Text(
          'Watchlist Detail',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPoster(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _readText('title', fallback: 'Untitled'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(
                        _readText('type', fallback: 'Movie').toUpperCase(),
                      ),
                      _buildChip(_readText('genre', fallback: 'Uncategorized')),
                      if (_readText('platform').isNotEmpty)
                        _buildChip(_readText('platform')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildStatusBadge(),
                      const Spacer(),
                      Text(
                        _formatRating(_item?['rating']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildInfoSection(
                    title: 'Last Watched',
                    content: _readText(
                      'last_watched',
                      fallback: 'No watching progress recorded.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    title: 'Personal Notes',
                    content: _readText(
                      'notes',
                      fallback: 'No personal notes yet.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoster() {
    final posterUrl = _readText('poster_url');

    return Container(
      width: double.infinity,
      height: 370,
      color: const Color(0xFF1E1E1E),
      child: posterUrl.isEmpty
          ? const Center(
              child: Text(
                'No Image Available',
                style: TextStyle(color: Color(0xFF777777), fontSize: 14),
              ),
            )
          : Image.network(
              posterUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE50914)),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text(
                    'Image Error',
                    style: TextStyle(color: Color(0xFF777777), fontSize: 14),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE1E1E1),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8E2028)),
      ),
      child: Text(
        _statusLabel(_item?['status']),
        style: const TextStyle(
          color: Color(0xFFFF747B),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoSection({required String title, required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF292929)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xFFBDBDBD),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Color(0xFF151515),
          border: Border(top: BorderSide(color: Color(0xFF292929))),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isDeleting ? null : _confirmDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Delete'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isDeleting ? null : _openEditSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_isDeleting ? 'Deleting...' : 'Edit Watchlist'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
