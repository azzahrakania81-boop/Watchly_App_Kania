import 'package:supabase_flutter/supabase_flutter.dart';

import '/app/models/watchlist.dart';


class SupabaseService {

  final SupabaseClient client =
      Supabase.instance.client;


  Future<List<Watchlist>> getWatchlists() async {

    final response = await client
        .from('watchlists')
        .select();


    return response
        .map<Watchlist>(
          (item) => Watchlist.fromJson(item),
        )
        .toList();

  }


  Future<void> addWatchlist(
      Watchlist watchlist) async {

    await client
        .from('watchlists')
        .insert(
          watchlist.toJson(),
        );

  }


  Future<void> updateWatchlist(
      Watchlist watchlist) async {

    await client
        .from('watchlists')
        .update(
          watchlist.toJson(),
        )
        .eq(
          'id',
          watchlist.id!,
        );

  }


  Future<void> deleteWatchlist(
      String id) async {

    await client
        .from('watchlists')
        .delete()
        .eq(
          'id',
          id,
        );

  }


  Future<AuthResponse> register(
  String email,
  String password,
) async {

  final response = await client.auth.signUp(
    email: email,
    password: password,
  );


  if(response.user != null){

    await client
        .from('profiles')
        .insert({

          'id': response.user!.id,
          'email': email,
          'username': email.split('@')[0],

        });

  }


  return response;

}


  Future<AuthResponse> login(
      String email,
      String password,
  ) async {

    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

  }


  Future<void> logout() async {

    await client.auth.signOut();

  }

}