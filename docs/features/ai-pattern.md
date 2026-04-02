# AI User Pattern Analysis

The **AI Pattern Analysis** feature automatically identifies long-term spending habits and financial behaviors by analyzing transaction history. Unlike the main chat interaction, this feature focuses on high-level patterns and stores them locally to personalize the user experience.

## Key Concepts

- **User Pattern**: A descriptive summary of financial behavior (e.g., "Frequent dine-out on weekends," "High subscription costs").
- **Context Snapshot**: A condensed, token-optimized representation of recent transaction data (categorized totals, money sources, and specific records).
- **Pattern Update**: A background process that periodically sends the context snapshot to a specialized AI endpoint to refresh the stored pattern.

## Architecture

### 1. AI Pattern Service
Located in `lib/services/ai_pattern_service.dart`, this singleton handles:
- Generating the context snapshot from `RecordRepository`.
- Managing the daily schedule for pattern updates.
- Orchestrating the API request to the server.

### 2. Configuration (`ApiConfig`)
Endpoints and API keys are managed in `lib/configs/api_config.dart`:
- `updateUserPatternPath`: The URL used for pattern analysis.
- `patternSyncApiKey`: The token used for authentication.

### 3. Persistence (`StorageService`)
- `keyUserPattern`: Stores the latest analyzed pattern string.
- `keyLastPatternUpdateTime`: Keeps track of the last successful update to avoid redundant daily calls.

## How it works

1. **Startup**: On app launch (`main.dart`), the app triggers `AiPatternService().updateUserPattern()`.
2. **Delta Check**: The service checks if a pattern has already been updated for the current day.
3. **Payload Generation**: If an update is due, it packages the last 90 days of history (for initial sync) or the delta since the last update.
4. **Analysis**: The payload is sent to the server.
5. **Storage**: The analyzed text returned by the AI is saved locally and can be accessed via `StorageService().getString(StorageService.keyUserPattern)`.

## Manual Testing
Developers can trigger a manual update via the **Test Tab** in the app using the **Test AI Sync** button, which uses a "force" flag to bypass the daily check.
