architecture

tooling
use fvm for all flutter and dart commands. flutter version is managed via .fvm/fvm_config.json (e.g. 3.35.7). run fvm flutter and fvm dart, not bare flutter/dart.

framework
flutter app with dart sdk ^3.9.2. material 3, google_fonts (poppins), flutter_dotenv for env. assets include .env.

state and di
provider package for ui state. multi provider in main.dart: AppConfig, StorageService, ChangeNotifierProvider for ChatProvider. use context.read<SomeProvider>() or context.watch where needed. providers hold ui reactive state only.

services
services are singletons. call them directly e.g. ApiService(), ChatApiService(), StorageService(), RecordRepository(). they do not hold conversational state. factory with optional config/client for tests. examples: ApiService, ChatApiService, StorageService.

singleton pattern
static final _instance and factory Name() => _instance. private constructor _internal(). init when needed via static Future init() and call from main before runApp.

repositories
data access layer. RecordRepository is a singleton, holds sqflite Database. init via RecordRepository.init() in main. uses path_provider for db path, optional asset copy for initial data.db. exposes create/get/update/delete for records and money sources. used by providers and screens.

config
AppConfig singleton. baseUrl, timeouts, api keys from dotenv (mainChatApiKey, etc). env from .env file loaded in main. never hardcode secrets.

initialization
main() must call async init before runApp: StorageService.init(), RecordRepository.init(), dotenv.load(fileName: ".env"). use Future.wait for parallel init.

networking
all http goes through ApiService. ApiService builds full url from AppConfig.baseUrl, delegates to APIHelper for get/post/postStream. specialized services like ChatApiService use ApiService (postStream), not APIHelper directly. ApiException for api errors.

testing
services allow injecting mocks via factory (e.g. ApiService with client and config). RecordRepository has setMockDatabase for tests. every service and provider should have a corresponding test. use mocktail. run fvm flutter test.
