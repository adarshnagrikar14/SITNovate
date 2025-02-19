import 'package:get_it/get_it.dart';
import 'package:sybot/core/api/api_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core
  sl.registerLazySingleton(() => ApiService());

  // Repositories
  // sl.registerLazySingleton<ChatRepository>(
  //   () => ChatRepositoryImpl(apiService: sl()),
  // );

  // Cubits
  // sl.registerFactory(() => ChatCubit(chatRepository: sl()));
}
