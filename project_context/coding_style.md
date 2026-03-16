coding style

simplicity
choose the most direct solution. avoid over-engineering and overly complex code. keep logic readable and minimal.

singleton services
services that do not hold conversational state are singletons and called directly e.g. ApiService(), RecordRepository(). no need to inject them via provider for that.

minimal boilerplate
reuse existing utilities e.g. APIHelper for repeated http logic. specialized services use ApiService so url and config stay in one place.

secrets
never hardcode keys or secrets. use .env and access via AppConfig (e.g. mainChatApiKey).

networking
all network calls go through ApiService. specialized services (e.g. ChatApiService) use ApiService, not APIHelper directly, so url and connection handling stay centralized.

state
use providers only for ui reactive state. services and repositories hold the actual logic and data access.

async init
initialize sync or high latency dependencies in main() before runApp, e.g. StorageService.init(), RecordRepository.init(), dotenv.load.

streams and delimited responses
when the response uses a delimiter (e.g. --//--), handle partial chunks carefully. ui should stop displaying at the first delimiter; background processing (e.g. extracting records) continues until the stream closes.

tests
every service or provider should have a corresponding test. run fvm flutter test before committing.

mocks
factory constructors in services allow injecting mocks or test config (e.g. ApiService with client and config, RecordRepository.setMockDatabase). use that for tests instead of duplicating logic.

follow existing patterns
match how the codebase already does things: same singleton style, same provider usage, same repo and model patterns. avoid introducing new patterns unless necessary.
