context

what the app is
wally ai is a mobile app to store and track expense and income. it is ai powered for convenience: users chat with an ai assistant that can parse natural language and create records (income/expense) from the conversation. the app persists records and money sources locally in sqlite and uses a remote chat api for the ai.

main flows
user opens chat screen, sends messages. chat goes to backend via ChatApiService stream. assistant replies stream back. when the ai returns structured data after a delimiter (--//--), the app parses json into Record objects and saves them via RecordRepository (creating money sources if needed). ui shows messages and can show saved records on the assistant message.

where to find things
lib/main.dart: app entry, provider setup, init of StorageService, RecordRepository, dotenv.
lib/screens/: chat_screen.dart (main ui). screens.dart barrel.
lib/components/: reusable widgets, dialogs (in popups folder). components.dart barrel.
lib/providers/: chat_provider.dart (chat state, send message, stream handling, record parsing and save). providers.dart barrel.
lib/services/: api_service.dart (http singleton), chat_api_service.dart (stream chat), storage_service.dart (shared_preferences singleton), api_exception.dart. services.dart barrel.
lib/repositories/: record_repository.dart (sqlite, records and money sources). repositories.dart barrel.
lib/models/: record.dart, money_source.dart, chat_message.dart, chat_stream_response.dart. models.dart barrel.
lib/configs/: app_config.dart (env, baseUrl, keys). configs.dart barrel.
lib/helpers/: api_helper.dart (low level get/post/stream). helpers.dart barrel.
test/: test files mirror lib (e.g. providers/chat_provider_test.dart, screens/chat_screen_test.dart).
.env: secrets (mainChatApiKey etc). not committed.
assets/database/: optional initial data.db for RecordRepository.

logic locations
chat stream and message handling: ChatProvider.sendMessage and stream subscription. display text vs full text and delimiter --//-- handling in the stream listener.
parsing ai response into records: in ChatProvider stream onDone, split by --//--, json decode, then create MoneySource by name if missing and createRecord for each.
all record and money source crud: RecordRepository (createRecord, getAllRecords, updateRecord, deleteRecord, createMoneySource, getAllMoneySources, getMoneySourceByName, etc).
api base url and keys: AppConfig (baseUrl, mainChatApiKey). .env for values.
http: ApiService get/post/postStream; ChatApiService uses postStream for /api/chat-flow/wallet-ai-chatbot.
