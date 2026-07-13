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
  State<AddWatchlistPage> createState() =>
      _AddWatchlistPageState();
}

class _AddWatchlistPageState extends State<AddWatchlistPage> {
  static const String _posterBucket = 'posters';

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _platformController =
      TextEditingController();

  final TextEditingController _ratingController =
      TextEditingController();

  final TextEditingController _lastWatchedController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  XFile? _selectedPoster;
  Uint8List? _posterBytes;

  bool _isSaving = false;

  String _selectedType = 'movie';
  String _selectedGenre = 'Action';
  String _selectedStatus = 'want_to_watch';

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

      _showMessage(
        'Gagal memilih poster: $error',
        isError: true,
      );
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

    final String extension =
        fileName.split('.').last.toLowerCase();

    const List<String> supportedExtensions = [
      'jpg',
      'jpeg',
      'png',
      'webp',
    ];

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

  Future<Map<String, String>?> _uploadPoster(
    String userId,
  ) async {
    if (_selectedPoster == null || _posterBytes == null) {
      return null;
    }

    final String extension =
        _getFileExtension(_selectedPoster!.name);

    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$extension';

    final String storagePath = '$userId/$fileName';

    await _supabase.storage
        .from(_posterBucket)
        .uploadBinary(
          storagePath,
          _posterBytes!,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: _getContentType(extension),
          ),
        );

    final String publicUrl = _supabase.storage
        .from(_posterBucket)
        .getPublicUrl(storagePath);

    debugPrint('Poster berhasil diunggah');
    debugPrint('Poster path: $storagePath');
    debugPrint('Poster URL: $publicUrl');

    return {
      'path': storagePath,
      'url': publicUrl,
    };
  }

  Future<void> _deleteUploadedPoster(
    String? storagePath,
  ) async {
    if (storagePath == null || storagePath.isEmpty) {
      return;
    }

    try {
      await _supabase.storage
          .from(_posterBucket)
          .remove([storagePath]);
    } catch (error) {
      debugPrint(
        'Gagal membersihkan poster sementara: $error',
      );
    }
  }

  Future<void> _saveWatchlist() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage(
        'Sesi login tidak ditemukan. Silakan login kembali.',
        isError: true,
      );
      return;
    }

    final String ratingText = _ratingController.text
        .trim()
        .replaceAll(',', '.');

    final double? rating = ratingText.isEmpty
        ? null
        : double.tryParse(ratingText);

    if (ratingText.isNotEmpty && rating == null) {
      _showMessage(
        'Rating harus berupa angka.',
        isError: true,
      );
      return;
    }

    if (rating != null && (rating < 0 || rating > 10)) {
      _showMessage(
        'Rating harus berada antara 0 sampai 10.',
        isError: true,
      );
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
        final Map<String, String>? posterResult =
            await _uploadPoster(user.id);

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
        'platform':
            _platformController.text.trim().isEmpty
                ? null
                : _platformController.text.trim(),
        'status': _selectedStatus,
        'rating': rating,
        'last_watched':
            _lastWatchedController.text.trim().isEmpty
                ? null
                : _lastWatchedController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      debugPrint('User ID: ${user.id}');
      debugPrint('Data watchlist: $data');

      await _supabase.from('watchlists').insert(data);

      saveSuccessful = true;

      debugPrint(
        'Watchlist berhasil disimpan ke Supabase.',
      );
    } on PostgrestException catch (error) {
      await _deleteUploadedPoster(uploadedPosterPath);

      debugPrint(
        'DATABASE ERROR\n'
        'Code: ${error.code}\n'
        'Message: ${error.message}\n'
        'Details: ${error.details}\n'
        'Hint: ${error.hint}',
      );

      if (mounted) {
        _showMessage(
          'Gagal menyimpan data: ${error.message}',
          isError: true,
        );
      }
    } catch (error, stackTrace) {
      await _deleteUploadedPoster(uploadedPosterPath);

      debugPrint(
        'UPLOAD ATAU GENERAL ERROR\n'
        'Error: $error\n'
        'Stack trace: $stackTrace',
      );

      if (mounted) {
        _showMessage(
          'Gagal mengunggah poster atau menyimpan data: '
          '$error',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }

    if (!saveSuccessful || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Watchlist berhasil ditambahkan.',
          ),
          backgroundColor: Color(0xFF237A3B),
          behavior: SnackBarBehavior.floating,
        ),
      );

    await Future<void>.delayed(
      const Duration(milliseconds: 400),
    );

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? const Color(0xFFB3261E)
              : const Color(0xFF237A3B),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: Color(0xFFFFA5AA),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF707070),
      ),
      filled: true,
      fillColor: const Color(0xFF242424),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF333333),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE50914),
          width: 1.3,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D0D),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: _isSaving
                ? null
                : () => Navigator.of(context).pop(),
            // Mengganti Icon arrow_back dengan widget Text biasa
            icon: const Text(
              'Back',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          title: const Text(
            'Add Watchlist',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                35,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPosterSection(),
                  const SizedBox(height: 26),

                  _buildSectionTitle('Title'),
                  const SizedBox(height: 9),

                  TextFormField(
                    controller: _titleController,
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _inputDecoration(
                      label: 'Movie or Series Title',
                      hint: 'Example: Interstellar',
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Title wajib diisi';
                      }

                      if (value.trim().length < 2) {
                        return 'Title terlalu pendek';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Type'),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          label: 'Movie',
                          value: 'movie',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeButton(
                          label: 'Series',
                          value: 'series',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Genre'),
                  const SizedBox(height: 9),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedGenre,
                    dropdownColor: const Color(0xFF242424),
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _inputDecoration(
                      label: 'Genre',
                      hint: 'Choose genre',
                    ),
                    items: _genres.map((genre) {
                      return DropdownMenuItem<String>(
                        value: genre,
                        child: Text(genre),
                      );
                    }).toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;

                            setState(() {
                              _selectedGenre = value;
                            });
                          },
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Platform'),
                  const SizedBox(height: 9),

                  TextFormField(
                    controller: _platformController,
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _inputDecoration(
                      label: 'Streaming Platform',
                      hint: 'Netflix, Disney+, Viu, Cinema',
                    ),
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Watching Status'),
                  const SizedBox(height: 9),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    dropdownColor: const Color(0xFF242424),
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _inputDecoration(
                      label: 'Status',
                      hint: 'Choose watching status',
                    ),
                    items: _statuses.map((status) {
                      return DropdownMenuItem<String>(
                        value: status['value'],
                        child: Text(status['label']!),
                      );
                    }).toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;

                            setState(() {
                              _selectedStatus = value;
                            });
                          },
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Rating'),
                  const SizedBox(height: 9),

                  TextFormField(
                    controller: _ratingController,
                    enabled: !_isSaving,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _inputDecoration(
                      label: 'Personal Rating',
                      hint: '0 - 10',
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return null;
                      }

                      final double? rating =
                          double.tryParse(
                        value
                            .trim()
                            .replaceAll(',', '.'),
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

                  const SizedBox(height: 22),

                  _buildSectionTitle('Last Watched'),
                  const SizedBox(height: 9),

                  TextFormField(
                    controller: _lastWatchedController,
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _inputDecoration(
                      label: 'Last Watched',
                      hint: 'Example: Season 2, Episode 5',
                    ),
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Personal Notes'),
                  const SizedBox(height: 9),

                  TextFormField(
                    controller: _notesController,
                    enabled: !_isSaving,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 500,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _inputDecoration(
                      label: 'Notes',
                      hint:
                          'Write your opinion or short review...',
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          _isSaving ? null : _saveWatchlist,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFE50914),
                        disabledBackgroundColor:
                            const Color(0xFF5B2225),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Watchlist',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w700,
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
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: _isSaving ? null : _pickPoster,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 155,
                  height: 215,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _posterBytes == null
                          ? const Color(0xFF454545)
                          : const Color(0xFFE50914),
                      width: 1.2,
                    ),
                  ),
                  child: _posterBytes == null
                      ? const Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              'Upload Poster',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Tap to choose image',
                              style: TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius:
                              BorderRadius.circular(13),
                          child: Image.memory(
                            _posterBytes!,
                            width: 155,
                            height: 215,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              if (_posterBytes != null)
                Positioned(
                  top: -9,
                  right: -9,
                  child: InkWell(
                    onTap:
                        _isSaving ? null : _removePoster,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 31,
                      height: 31,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE50914),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'X',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSaving ? null : _pickPoster,
            style: TextButton.styleFrom(
              foregroundColor:
                  const Color(0xFFFFA5AA),
            ),
            child: Text(
              _posterBytes == null
                  ? 'Choose Poster'
                  : 'Change Poster',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required String value,
  }) {
    final bool selected = _selectedType == value;

    return InkWell(
      onTap: _isSaving
          ? null
          : () {
              setState(() {
                _selectedType = value;
              });
            },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE50914)
              : const Color(0xFF242424),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFFE50914)
                : const Color(0xFF3A3A3A),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}