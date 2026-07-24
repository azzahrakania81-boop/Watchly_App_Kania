import '/resources/pages/register_page.dart';
import '/resources/pages/login_page.dart';
import '/resources/pages/welcome_page.dart';
import '/resources/pages/home_page.dart';
import '/resources/pages/add_watchlist_page.dart';
import '/resources/pages/not_found_page.dart';
import '/resources/pages/detail_watchlist_page.dart';
import '/resources/pages/profile_page.dart';
import 'package:nylo_framework/nylo_framework.dart';

appRouter() => nyRoutes((router) {
  router.add(WelcomePage.path).initialRoute();
  router.add(LoginPage.path);
  router.add(RegisterPage.path);
  router.add(HomePage.path);
  router.add(AddWatchlistPage.path);
  router.add(NotFoundPage.path).unknownRoute();
  router.add(DetailWatchlistPage.path);
  router.add(ProfilePage.path);
});