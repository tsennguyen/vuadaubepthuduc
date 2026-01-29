# AdminChatModerationController Disposal Fix

## Problem
The app was crashing with the error:
```
DartError: Bad state: Tried to use AdminChatModerationController after `dispose` was called.
```

This occurred when navigating away from the Admin Chat Moderation page while async operations (stream listeners) were still active.

## Root Cause
The issue was caused by **double disposal** of the `AdminChatModerationController`:

1. **Line 271** - The provider was manually calling `ref.onDispose(controller.dispose)`
2. Riverpod's `AutoDisposeStateNotifierProvider` **already automatically calls** the `dispose()` method when the provider is disposed
3. This caused `dispose()` to be called **twice**, leading to attempts to modify state after disposal

## Solution Applied

### Fix 1: Remove Manual Disposal (CRITICAL)
**File**: `lib/features/admin/application/admin_chat_moderation_controller.dart`

**Before:**
```dart
final adminChatModerationControllerProvider = AutoDisposeStateNotifierProvider<
    AdminChatModerationController, AdminChatModerationState>((ref) {
  final repo = ref.watch(adminChatModerationRepositoryProvider);
  final controller = AdminChatModerationController(repo);
  ref.onDispose(controller.dispose);  // ❌ REDUNDANT - causes double disposal!
  return controller;
});
```

**After:**
```dart
final adminChatModerationControllerProvider = AutoDisposeStateNotifierProvider<
    AdminChatModerationController, AdminChatModerationState>((ref) {
  final repo = ref.watch(adminChatModerationRepositoryProvider);
  return AdminChatModerationController(repo);  // ✅ Riverpod handles disposal
});
```

### Fix 2: Enhanced Subscription Cleanup
**File**: `lib/features/admin/application/admin_chat_moderation_controller.dart`

Added additional safety checks to the `_subscribe()` method:

```dart
void _subscribe() {
  _sub?.cancel();
  _sub = null;           // ✅ Explicitly null out the subscription
  
  if (!mounted) return;  // ✅ Don't create new subscriptions if disposed
  
  state = state.copyWith(
    violations: const AsyncValue.loading(),
    lastError: null,
  );

  _sub = _repository.watchViolations(state.filter).listen(
    (data) {
      if (!mounted) return;  // ✅ Already present, keeps state safe
      state = state.copyWith(
        violations: AsyncValue.data(data),
        lastError: null,
      );
    },
    onError: (error, stack) {
      if (!mounted) return;  // ✅ Already present, keeps state safe
      state = state.copyWith(
        violations: AsyncValue.error(error, stack),
        lastError: '$error',
      );
    },
  );
}
```

## Why This Happens

### Riverpod's AutoDispose Lifecycle
When using `AutoDisposeStateNotifierProvider`, Riverpod automatically:
1. Calls the `dispose()` method of the StateNotifier when the provider is no longer used
2. Cancels all watchers and dependencies
3. Cleans up resources

### The Anti-Pattern
Manually adding `ref.onDispose(controller.dispose)` creates a double-disposal scenario:
1. First disposal: When ref is disposed, it calls `controller.dispose()`
2. Second disposal: Riverpod's automatic disposal also calls `controller.dispose()`

This causes the StateNotifier to be marked as disposed twice, and any pending async operations that try to update state will throw the "used after dispose" error.

## Testing the Fix
1. Navigate to the Admin Chat Moderation page
2. Let violations load
3. Navigate away from the page quickly (before all data is loaded)
4. **Expected**: No error, clean disposal
5. **Previous behavior**: Crash with "Tried to use after dispose" error

## Best Practices for Riverpod StateNotifiers

### ✅ DO
- Let Riverpod handle disposal automatically with `AutoDisposeStateNotifierProvider`
- Check `mounted` before modifying state in async callbacks
- Cancel subscriptions in the `dispose()` method

### ❌ DON'T
- Manually call `ref.onDispose(controller.dispose)` with `AutoDisposeStateNotifierProvider`
- Modify state in callbacks without checking `mounted`
- Create new subscriptions if the notifier is already disposed

## Related Files Modified
1. `lib/features/admin/application/admin_chat_moderation_controller.dart` - Fixed double disposal and enhanced subscription cleanup
2. `lib/features/admin/application/admin_settings_controller.dart` - Fixed same double disposal pattern

## Impact
- ✅ Fixes crash when navigating away from Admin Chat Moderation page
- ✅ Fixes potential crash when navigating away from Admin Settings page
- ✅ Improves app stability for all admin moderation workflows
- ✅ Prevents memory leaks from uncancelled subscriptions
- ✅ Establishes correct pattern for using AutoDisposeStateNotifierProvider throughout the app

