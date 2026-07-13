import 'package:nylo_framework/nylo_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/watchlist.dart';
import 'controller.dart';

class HomeWatchlistController extends Controller {
  final supabase = Supabase.instance.client;

  String selectedGenre = 'All';
  String selectedStatus = 'Want to Watch';
  String searchQuery = '';

  Future<List<Watchlist>> fetchWatchlist() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      var query = supabase.from('watchlist').select().eq('user_id', user.id);
      
      // filter sesuai status
      query = query.eq('status', selectedStatus);

      // cek genre
      if (selectedGenre != 'All') {
        query = query.eq('genre', selectedGenre);
      }

      // search bar
      if (searchQuery.isNotEmpty) {
        query = query.ilike('title', '%$searchQuery%');
      }

      final res = await query;
      return (res as List).map((e) => Watchlist.fromJson(e)).toList();
    } catch (e) {
      print('error get data: $e');
      return [];
    }
  }
}