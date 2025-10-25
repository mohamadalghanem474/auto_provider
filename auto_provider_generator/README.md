# auto_provider_generator

`auto_provider_generator` scans your Flutter project for widgets annotated with
`@AutoProvid()` and builds a complete auto-wired routing layer in
`lib/core/router/auto_provider.dart`. The generated file:

- Wraps each annotated screen with the Bloc/Cubit dependencies listed in the
  annotation.
- Provides an `AutoProvider` navigator observer that logs transitions and keeps
  track of the current location.
- Resets lazy singletons registered in `get_it` when their routes are popped so
  they do not leak state across screens.

## How it works

1. The builder finds every Bloc/Cubit/HydratedBloc in `lib/**.dart`.
2. It matches all widgets annotated with `@AutoProvid()` and reads the
   dependency list plus the `static const routeName` on the widget.
3. It emits:
   - Imports for every referenced Bloc/Cubit and screen.
   - `BlocProvider`/`MultiBlocProvider` wrappers per route.
   - A navigator observer and helper methods (`find`, `onGenerateRoute`,
     `navigatorKey`, etc.).

## Setup

```yaml
dependencies:
  auto_provider_annotation:

dev_dependencies:
  auto_provider_generator:
  build_runner:
```

## Running the generator

From the root of the consuming package:

```bash
dart run build_runner build       # one-off generation
# or
dart run build_runner watch       # keep it fresh during development
```

Whenever you add a new screen or update dependencies, rerun the builder so
`lib/core/router/auto_provider.dart` stays in sync.

## Using the generated router

```dart
import 'package:your_app/core/router/auto_provider.dart';

MaterialApp(
  navigatorKey: AutoProvider.navigatorKey,
  navigatorObservers: [AutoProvider.observer],
  onGenerateRoute: AutoProvider.onGenerateRoute,
);
```

You can also call `AutoProvider.find(routeName)` to get the widget for a route,
for example when driving a custom navigation stack.

## Tips

- Make sure every annotated widget exposes a unique `static const routeName`.
- Register your Blocs/Cubits as lazy singletons inside `get_it` so the generated
  cleanup code can dispose of them when their routes leave the stack.
- Turn on `AutoProvider.enableLogging` during development to see route changes
  in the console.
