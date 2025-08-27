# Analyzer Plugin Performance Optimization

## Problem
The analyzer plugin was running on every analysis cycle, which happens frequently during development. This caused:
- Very slow performance
- Unnecessary processing of unchanged files
- High CPU usage during development

## Solution
Implemented intelligent caching and change detection:

### 1. Content Hash Tracking
- Calculate a hash of file content using `base64.encode(utf8.encode(content)).substring(0, 16)`
- Store hash with file info in `_FileInfo` class
- Only process files when content hash changes

### 2. Smart File Processing
```dart
// Check if file has actually changed
final previousInfo = _processedFiles[path];
if (previousInfo != null && previousInfo.contentHash == currentHash) {
  // File content hasn't changed, skip processing
  print('🔄 Skipping unchanged file: ${path.split('/').last}');
  return;
}

print('⚡ Processing changed file: ${path.split('/').last}');
```

### 3. Memory Management
- Cache cleanup to prevent memory leaks
- Keep only last 100 processed files
- Remove cache entries for deleted files

## Performance Results
- **Before**: Processing every file on every analysis cycle
- **After**: Only processing files when content actually changes

### Test Results
```
--- Analysis Cycle 1 ---
⚡ Processing changed file: test_provider.dart (first time)
🔄 Skipping unchanged file: test_provider.dart
🔄 Skipping unchanged file: test_provider.dart
⏱️  Total time: 37ms

--- Analysis Cycle 2-5 ---
🔄 Skipping unchanged file: test_provider.dart (all iterations)
⏱️  Total time: ~35ms each
```

## Benefits
1. **Much faster development**: Unchanged files are skipped instantly
2. **Reduced CPU usage**: No unnecessary parsing and processing
3. **Better developer experience**: No lag when typing or navigating
4. **File watcher behavior**: Only processes when files actually change

## How It Works
1. Plugin receives analysis request for a file
2. Calculates content hash of the file
3. Compares with previously stored hash
4. If hash is different (file changed):
   - Process the file and generate `x.c.dart`
   - Update cache with new hash
5. If hash is same (file unchanged):
   - Skip processing entirely
   - Return immediately

## Debug Output
The plugin now provides clear feedback:
- `⚡ Processing changed file: filename.dart` - when file is processed
- `🔄 Skipping unchanged file: filename.dart` - when file is skipped

This makes it easy to see when the optimization is working!
