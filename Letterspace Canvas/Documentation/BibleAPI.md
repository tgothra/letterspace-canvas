# Bible API Documentation

## API Overview
API.Bible provides a RESTful API for accessing multiple Bible translations and versions. This documentation covers the endpoints we're using in the Letterspace Canvas application.

## Base URL
```
https://api.scripture.api.bible/v1
```

## Authentication
- API Key: Required in header as `api-key`
- Current API Key: `c188be8322a8a1d53c2e47fb09a0f658`

## Bible Versions
Currently using:
- King James Version (KJV) - ID: `de4e12af7f28f599-01`

## Available Endpoints

### 1. Search Verses
Search for verses across the Bible.

```
GET /bibles/{bibleId}/search
```

Parameters:
- `query` (required): Search term (e.g., "John 3:16" or "love")
- `limit` (optional): Number of results (default: 10)
- `offset` (optional): Starting position
- `sort` (optional): Sort order ("relevance", "canonical")

Example:
```bash
curl -H "api-key: YOUR_API_KEY" \
     "https://api.scripture.api.bible/v1/bibles/de4e12af7f28f599-01/search?query=John%203:16"
```

Response:
```json
{
  "data": {
    "query": "John 3:16",
    "passages": [{
      "id": "JHN.3.16",
      "orgId": "JHN.3.16",
      "bibleId": "de4e12af7f28f599-01",
      "bookId": "JHN",
      "reference": "John 3:16",
      "content": "<p>For God so loved the world...</p>"
    }]
  }
}
```

### 2. Get Verse
Get a specific verse by reference.

```
GET /bibles/{bibleId}/verses/{verseId}
```

Example:
```bash
curl -H "api-key: YOUR_API_KEY" \
     "https://api.scripture.api.bible/v1/bibles/de4e12af7f28f599-01/verses/JHN.3.16"
```

Response:
```json
{
  "data": {
    "id": "JHN.3.16",
    "orgId": "JHN.3.16",
    "bookId": "JHN",
    "reference": "John 3:16",
    "content": "<p>For God so loved the world...</p>",
    "verseCount": 1
  }
}
```

### 3. Get Chapter
Get all verses in a chapter.

```
GET /bibles/{bibleId}/chapters/{chapterId}
```

Example:
```bash
curl -H "api-key: YOUR_API_KEY" \
     "https://api.scripture.api.bible/v1/bibles/de4e12af7f28f599-01/chapters/JHN.3"
```

### 4. Get Book
Get information about a specific book.

```
GET /bibles/{bibleId}/books/{bookId}
```

Example:
```bash
curl -H "api-key: YOUR_API_KEY" \
     "https://api.scripture.api.bible/v1/bibles/de4e12af7f28f599-01/books/JHN"
```

## Error Handling

The API returns standard HTTP status codes:
- 200: Success
- 400: Bad Request
- 401: Unauthorized (invalid API key)
- 404: Not Found
- 429: Too Many Requests
- 500: Server Error

Error Response Format:
```json
{
  "statusCode": 400,
  "error": "Bad Request",
  "message": "Invalid verse reference"
}
```

## Rate Limits
- 5000 requests per day
- 60 requests per minute

## Implementation Notes

### Content Format
The API returns verse content with HTML markup. Our implementation:
1. Strips HTML tags
2. Normalizes whitespace
3. Handles special characters

### Verse References
Format: `{BOOK}.{CHAPTER}.{VERSE}`
Example: `JHN.3.16` for John 3:16

### Search Tips
1. Use exact references for precise matches (e.g., "John 3:16")
2. Use keywords for thematic searches (e.g., "love", "faith")
3. Use book names or abbreviations (e.g., "Psalms", "PSA")

## Code Examples

### Swift Implementation
```swift
// Search for verses
let verses = try await BibleAPI.searchVerses(query: "John 3:16")

// Get a specific verse
let verse = try await BibleAPI.getVerse(id: "JHN.3.16")

// Get a chapter
let chapter = try await BibleAPI.getChapter(id: "JHN.3")
```

## Future Improvements
1. Add caching for frequently accessed verses
2. Implement verse comparison between translations
3. Add support for multiple Bible versions
4. Add verse of the day feature
5. Implement offline mode with local storage