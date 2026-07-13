import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/bootstrap/env.g.dart';
import 'package:nylo_framework/nylo_framework.dart';

import 'bootstrap/boot.dart';
import '/config/supabase.dart';


void main() async {

  WidgetsFlutterBinding.ensureInitialized();


  await Supabase.initialize(

    url: SupabaseConfig.url,

    anonKey: SupabaseConfig.anonKey,

  );


  await Nylo.init(

    env: Env.get,

    setup: Boot.nylo(),

    appLifecycle: {

      AppLifecycleState.resumed: () {

      },

      AppLifecycleState.paused: () {

      },

    },

  );

}