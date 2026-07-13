import 'package:nylo_framework/nylo_framework.dart';

class Watchlist extends Model {

  static const String storageKey = "watchlist";

  String? id;
  String? userId;
  String title;
  String? posterUrl;
  String? type;
  String? genre;
  String? platform;
  String? status;
  int? rating;
  String? notes;
  String? lastWatched;

  Watchlist({
    this.id,
    this.userId,
    required this.title,
    this.posterUrl,
    this.type,
    this.genre,
    this.platform,
    this.status,
    this.rating,
    this.notes,
    this.lastWatched,
  }) : super(key: storageKey);


  Watchlist.fromJson(Map<String, dynamic> data)
      : id = data['id'],
        userId = data['user_id'],
        title = data['title'] ?? '',
        posterUrl = data['poster_url'],
        type = data['type'],
        genre = data['genre'],
        platform = data['platform'],
        status = data['status'],
        rating = data['rating'],
        notes = data['notes'],
        lastWatched = data['last_watched'],
        super(key: storageKey);


  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'poster_url': posterUrl,
      'type': type,
      'genre': genre,
      'platform': platform,
      'status': status,
      'rating': rating,
      'notes': notes,
      'last_watched': lastWatched,
    };
  }

}