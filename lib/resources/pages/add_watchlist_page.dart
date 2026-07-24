import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddWatchlistPage extends StatefulWidget {
  static RouteView path = (
    '/add-watchlist',
    (_) => const AddWatchlistPage(),
  );

  const AddWatchlistPage({super.key});

  @override
  State<AddWatchlistPage> createState() => _AddWatchlistPageState();
}

class _AddWatchlistPageState extends State<AddWatchlistPage> {
  static const String _posterBucket = 'posters';

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _platformController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _lastWatchedController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  XFile? _selectedPoster;
  Uint8List? _posterBytes;

  bool _isSaving = false;

  String _selectedType = 'movie';
  String _selectedGenre = 'Romance';
  String _selectedStatus = 'want_to_watch';

  final List<String> _genres = const [
    'Romance',
    'Action',
    'Comedy',
    'Sci-Fi',
    'Horror',
    'Anime',
    'Fantasy',
    'Drama',
  ];

  final List<Map<String, String>> _statuses = const [
    {
      'value': 'want_to_watch',
      'label': 'Want to Watch',
    },
    {
      'value': 'watching',
      'label': 'Watching',
    },
    {
      'value': 'finished',
      'label': 'Finished',
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _platformController.dispose();
    _ratingController.dispose();
    _lastWatchedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPoster() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedPoster = image;
        _posterBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('Gagal memilih poster: $error', isError: true);
    }
  }

  void _removePoster() {
    if (_isSaving) return;

    setState(() {
      _selectedPoster = null;
      _posterBytes = null;
    });
  }

  String _getFileExtension(String fileName) {
    if (!fileName.contains('.')) {
      return 'jpg';
    }
    final String extension = fileName.split('.').last.toLowerCase();
    const List<String> supportedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
    if (!supportedExtensions.contains(extension)) {
      return 'jpg';
    }
    return extension;
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<Map<String, String>?> _uploadPoster(String userId) async {
    if (_selectedPoster == null || _posterBytes == null) {
      return null;
    }

    final String extension = _getFileExtension(_selectedPoster!.name);
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final String storagePath = '$userId/$fileName';

    await _supabase.storage.from(_posterBucket).uploadBinary(
          storagePath,
          _posterBytes!,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: _getContentType(extension),
          ),
        );

    final String publicUrl = _supabase.storage.from(_posterBucket).getPublicUrl(storagePath);
    return {'path': storagePath, 'url': publicUrl};
  }

  Future<void> _deleteUploadedPoster(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      await _supabase.storage.from(_posterBucket).remove([storagePath]);
    } catch (error) {
      debugPrint('Gagal membersihkan poster sementara: $error');
    }
  }

  Future<void> _saveWatchlist() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) return;

    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Sesi login tidak ditemukan. Silakan login kembali.', isError: true);
      return;
    }

    final String ratingText = _ratingController.text.trim().replaceAll(',', '.');
    final double? rating = ratingText.isEmpty ? null : double.tryParse(ratingText);

    if (ratingText.isNotEmpty && rating == null) {
      _showMessage('Rating harus berupa angka.', isError: true);
      return;
    }

    if (rating != null && (rating < 0 || rating > 10)) {
      _showMessage('Rating harus berada antara 0 sampai 10.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    String? uploadedPosterPath;
    bool saveSuccessful = false;

    try {
      String? posterUrl;
      if (_selectedPoster != null) {
        final Map<String, String>? posterResult = await _uploadPoster(user.id);
        if (posterResult != null) {
          uploadedPosterPath = posterResult['path'];
          posterUrl = posterResult['url'];
        }
      }

      final Map<String, dynamic> data = {
        'user_id': user.id,
        'title': _titleController.text.trim(),
        'poster_url': posterUrl,
        'type': _selectedType,
        'genre': _selectedGenre,
        'platform': _platformController.text.trim().isEmpty ? null : _platformController.text.trim(),
        'status': _selectedStatus,
        'rating': rating,
        'last_watched': _lastWatchedController.text.trim().isEmpty ? null : _lastWatchedController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      await _supabase.from('watchlists').insert(data);
      saveSuccessful = true;

    } on PostgrestException catch (error) {
      await _deleteUploadedPoster(uploadedPosterPath);
      if (mounted) _showMessage('Gagal menyimpan data: ${error.message}', isError: true);
    } catch (error) {
      await _deleteUploadedPoster(uploadedPosterPath);
      if (mounted) _showMessage('Gagal mengunggah poster atau menyimpan data.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (!saveSuccessful || !mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Watchlist berhasil ditambahkan.'),
          backgroundColor: Color(0xFF237A3B),
          behavior: SnackBarBehavior.floating,
        ),
      );

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFB3261E) : const Color(0xFF237A3B),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 13,
      ),
      filled: true,
      fillColor: const Color(0xff2A0A0E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF3B3B), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF3B3B), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: const Color(0xff120708),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Custom App Bar
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFF3B3B), width: 1.5),
                        ),
                        child: IconButton(
                          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: Color(0xFFFF3B3B), size: 20),
                        ),
                      ),
                      const SizedBox(width: 24),
                      const Text(
                        'Add Watchlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  _buildPosterSection(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Title'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(hint: 'Movie or series title'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Title wajib diisi';
                      if (value.trim().length < 2) return 'Title terlalu pendek';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Type'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildTypeButton(label: 'Movie', value: 'movie')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTypeButton(label: 'Series', value: 'series')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Genre'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _genres.map((genre) {
                      final bool isSelected = _selectedGenre == genre;
                      return GestureDetector(
                        onTap: _isSaving ? null : () => setState(() => _selectedGenre = genre),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF3B3B) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFF3B3B)),
                          ),
                          child: Text(
                            genre,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Platform'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _platformController,
                              enabled: !_isSaving,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(hint: 'Netflix, Viu, Prime, ...'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Status'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFF3B3B)),
                              dropdownColor: const Color(0xff2A0A0E),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: _inputDecoration(hint: 'Want to Watch'),
                              items: _statuses.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status['value'],
                                  child: Text(status['label']!),
                                );
                              }).toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      if (value != null) setState(() => _selectedStatus = value);
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Rating'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _ratingController,
                              enabled: !_isSaving,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(hint: '★ ★ ★ ★ ★'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Last Watched'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _lastWatchedController,
                              enabled: !_isSaving,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(hint: 'Optional'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Personal Notes'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    enabled: !_isSaving,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(hint: 'Write personal notes...'),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveWatchlist,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B3B),
                        disabledBackgroundColor: const Color(0xFFFF3B3B).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'SAVE WATCHLIST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterSection() {
    return InkWell(
      onTap: _isSaving ? null : _pickPoster,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF3B3B)),
        ),
        child: _posterBytes == null
            ? Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B3B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload Poster',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add movie or series cover',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _posterBytes!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: InkWell(
                      onTap: _isSaving ? null : _removePoster,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B3B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTypeButton({required String label, required String value}) {
    final bool selected = _selectedType == value;
    return InkWell(
      onTap: _isSaving ? null : () => setState(() => _selectedType = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF3B3B) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF3B3B)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}