# Bible API Documentation (bible-api.com)

## Overview
A simple, free, and RESTful Bible API from [github.com/wldeh/bible-api](https://github.com/wldeh/bible-api).

## Base URL
```
https://bible-api.com
```

## Features
- No API key required
- No rate limits
- Returns clean text (no HTML)
- Supports multiple translations
- Supports verse ranges

## Endpoints

### Get Verse(s)
```
GET /{reference}
```

Examples:
- Single verse: `GET /john 3:16`
- Multiple verses: `GET /john 3:16-17`
- Entire chapter: `GET /john 3`

Response Format:
```json
{
  "reference": "John 3:16",
  "verses": [
    {
      "book_id": "JHN",
      "book_name": "John",
      "chapter": 3,
      "verse": 16,
      "text": "For God so loved the world..."
    }
  ],
  "text": "For God so loved the world...",
  "translation_id": "web",
  "translation_name": "World English Bible",
  "translation_note": "Public Domain"
}
```

### Specify Translation
Add translation to the query string:
```
GET /{reference}?translation=kjv
```

Available translations:
- `web` - World English Bible (default)
- `kjv` - King James Version
- `clementine` - Clementine Latin Vulgate
- `almeida` - João Ferreira de Almeida
- `rccv` - Romanian Corrected Cornilescu Version

## Usage Examples

### Basic Verse Lookup
```bash
# Get John 3:16
curl https://bible-api.com/john%203:16

# Get John 3:16-17 (verse range)
curl https://bible-api.com/john%203:16-17

# Get John 3 (entire chapter)
curl https://bible-api.com/john%203
```

### With Specific Translation
```bash
# Get John 3:16 in KJV
curl https://bible-api.com/john%203:16?translation=kjv
```

## Swift Implementation
```swift
// Search for a verse
let verse = try await BibleAPI.searchVerses(query: "john 3:16")

// Get a verse range
let verses = try await BibleAPI.searchVerses(query: "john 3:16-17")

// Get with specific translation
let kjvVerse = try await BibleAPI.searchVerses(query: "john 3:16?translation=kjv")
```

## Error Handling
The API returns standard HTTP status codes:
- 200: Success
- 404: Verse not found
- 500: Server error

## Tips
1. References are case-insensitive
2. Spaces in references can be replaced with + or %20
3. Book names can be abbreviated (e.g., "jn" for "john")
4. Chapter and verse must be separated by a colon
5. Verse ranges use a hyphen (e.g., "3:16-17")

## Limitations
1. Only returns one translation at a time
2. No search functionality (must know the reference)
3. No fuzzy matching for book names
4. Limited number of translations available

## Future Improvements
1. Add caching for frequently accessed verses
2. Add support for parallel translations
3. Add verse of the day feature
4. Add offline mode with local storage
5. Add fuzzy matching for book names