# auto_provider_generator

`auto_provider_generator` scans your Flutter project for widgets annotated with
`@AutoProvid()` and builds a complete auto-wired routing layer in
`lib/core/router/auto_provider.dart`.

The generated file:

- Wraps each annotated screen with the Bloc/Cubit dependencies listed in the
  annotation.
- Provides an `AutoProvider` navigator observer that logs transitions and keeps
  track of the current location.
- Resets lazy singletons registered in `get_it` when their routes are popped so
  they do not leak state across screens.

---

## How it works

1. The builder finds every Bloc/Cubit/HydratedBloc in `lib/**.dart`.
2. It matches all widgets annotated with `@AutoProvid()` and reads the
   dependency list plus the `static const routeName` on the widget.
3. It emits:
   - Imports for every referenced Bloc/Cubit and screen.
   - `BlocProvider`/`MultiBlocProvider` wrappers per route.
   - A navigator observer and helper methods (`find`, `onGenerateRoute`,
     `navigatorKey`, etc.).

---

## Setup

```yaml
dependencies:
  auto_provider_annotation:

dev_dependencies:
  auto_provider_generator:
  build_runner:
```

---

## Running the generator

From the root of the consuming package:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Whenever you add a new screen or update dependencies, rerun the builder so
`lib/core/router/auto_provider.dart` stays in sync.

---

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

---

## Registering Cubits and Blocs

To ensure that your Cubits or Blocs are correctly managed by `AutoProvider`, register them as **lazy singletons** in `get_it` and mark their disposal methods with `@disposeMethod`.

### Example

```dart
// ensure add @lazySingleton
@lazySingleton
class ExampleCubit extends Cubit<int> {
  ExampleCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);

  // ensure add @disposeMethod
  @disposeMethod
  @override
  Future<void> close() async {
    super.close();
  }
}
```

This ensures that:

- The Cubit is **auto-registered** once and reused across screens.
- When its associated route is popped, the generated code automatically calls
  `close()` to dispose it safely and prevent memory leaks.

---

## Customizing Routing Behavior

If you’re using `AutoProvider.defaultOnGenerateRoute`, all routes annotated with
`@AutoProvid()` will automatically be included.  
However, you can **mix and match**—combine `@AutoProvid()` screens with your own
custom `onGenerateRoute` logic for full control over transitions or special cases.

### Example

## If using defaultOnGenerateRoute, you must add @AutoProvid() on all routes

## You can still customize transitions with PageRouteBuilder inside your own

## onGenerateRoute function. You can also mix both approaches

```dart
class AppRouter {
  static Route onGenerateRoute(RouteSettings settings) {
    if (AutoProvider.managedRoutes.contains(settings.name)) {
      /// Managed by AutoProvider
      switch (settings.name) {
        case HomeScreen.routeName:
          /// Managed by AutoProvider with custom transition
          return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return AutoProvider.find(settings.name);
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: Duration(milliseconds: 200),
          );
        default:
          /// Managed by AutoProvider without custom transition
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AutoProvider.find(settings.name),
          );
      }
    } else {
      /// Routes not managed by AutoProvider
      switch (settings.name) {
        case SplashScreen.routeName:
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => SplashScreen(),
          );
        default:
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => Scaffold(
              body: Center(
                child: Text('No route defined for ${settings.name}'),
              ),
            ),
          );
      }
    }
  }
}
```

This approach allows you to have:

- **Auto-managed routes** with automatic dependency injection.
- **Custom transitions** for specific screens.
- **Manual routes** for splash or onboarding screens that don’t need AutoProvider.

---

## Tips

- Make sure every annotated widget exposes a unique `static const routeName`.
- Register your Blocs/Cubits as lazy singletons inside `get_it` so the generated
  cleanup code can dispose of them when their routes leave the stack.
- Turn on `AutoProvider.enableLogging` during development to see route changes
  in the console.

---

## License

MIT
