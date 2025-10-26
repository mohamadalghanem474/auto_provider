# auto_provider_generator

`auto_provider_generator` is a code generator that automatically builds a complete, dependency-aware routing layer for Flutter apps.  
It scans your project for widgets annotated with `@AutoProvid()` and generates a fully configured router in:

```dart
lib/core/router/auto_provider.dart
```

This allows you to write less boilerplate when managing navigation and dependency injection using **Bloc/Cubit** and **get_it**.

---

## ✨ Features

- ✅ Automatically wraps annotated screens with `BlocProvider` or `MultiBlocProvider`.
- ✅ Generates imports and route definitions automatically.
- ✅ Provides an `AutoProvider` navigator observer for tracking navigation.
- ✅ Disposes registered Blocs/Cubits when their routes are popped (no leaks!).
- ✅ Integrates seamlessly with `get_it` and `injectable`.

---

## ⚙️ Setup

Add dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  get_it:
  bloc:
  injectable:
  auto_provider_annotation:
dev_dependencies:
  build_runner:
  injectable_generator:
  auto_provider_generator:
```

Run the builder once, or continuously during development:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 🧱 Registering Cubits and Blocs

To ensure that your Cubits or Blocs are correctly managed by `AutoProvider`, register them as **lazy singletons** in `get_it` and mark their disposal methods with `@disposeMethod`.

### Example

```dart
@lazySingleton
class ExampleCubit extends Cubit<int> {
  ExampleCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);

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
  `close()` to safely dispose of it and prevent memory leaks.

---

## 🧩 Annotating Screens

To register a screen with `AutoProvider`, annotate it with `@AutoProvid()` and
list the Cubits/Blocs it depends on.

```dart
@AutoProvid([ExampleCubit])
class ExampleScreen extends StatelessWidget {
  static const routeName = '/example';
  const ExampleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Example')),
      body: BlocBuilder<ExampleCubit, int>(
        builder: (context, state) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have pushed the button this many times:'),
                Text('$state',
                    style: Theme.of(context).textTheme.headline4),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => context.read<ExampleCubit>().increment(),
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => context.read<ExampleCubit>().decrement(),
            tooltip: 'Decrement',
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
```

---

## ⚡ How it works

1. Scans all Dart files under `lib/**.dart`.
2. Detects all widgets annotated with `@AutoProvid()`.
3. Extracts their dependency list and route names.
4. Generates the following:
   - Route registration in `auto_provider.dart`
   - Dependency wrappers (BlocProvider / MultiBlocProvider)
   - Navigator observer (`AutoProvider.observer`)
   - Helpers: `AutoProvider.find()`, `AutoProvider.defaultOnGenerateRoute()`, etc.

---

## 🚀 Using the Generated Router

```dart
import 'package:your_app/core/router/auto_provider.dart';

MaterialApp(
  navigatorKey: AutoProvider.navigatorKey,
  navigatorObservers: [AutoProvider.observer],
  onGenerateRoute: AutoProvider.defaultOnGenerateRoute,
);
```

You can also call `AutoProvider.find(routeName)` to retrieve a widget by its route name when managing a custom navigation stack.

---

## 🎨 Customizing Routing Behavior

If you’re using `AutoProvider.defaultOnGenerateRoute`, all routes annotated with
`@AutoProvid()` are included automatically.  
You can **combine it** with your own `onGenerateRoute` logic for custom transitions or special cases.

## Caese With Trransition

```dart
class AppRouter {
  static Route onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
        case HomeScreen.routeName:
          return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                AutoProvider.find(settings.name),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 200),
          );
        default:
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AutoProvider.find(settings.name),
          );
      }
  }
}
```

## Caese With Mix AutoProvider and Custom Route

```dart
class AppRouter {
  static Route onGenerateRoute(RouteSettings settings) {
    if (AutoProvider.managedRoutes.contains(settings.name)) {
      // Managed by AutoProvider
      switch (settings.name) {
        case HomeScreen.routeName:
          // With custom transition
          return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                AutoProvider.find(settings.name),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 200),
          );
        default:
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AutoProvider.find(settings.name),
          );
      }
    } else {
      // Not managed by AutoProvider
      switch (settings.name) {
        case SplashScreen.routeName:
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const SplashScreen(),
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

### Benefits of this approach

- **Automatic dependency injection** via generated Bloc providers.  
- **Customizable transitions** for any specific route.  
- **Manual control** for splash or onboarding flows.  

---

## 💡 Tips

- Each annotated widget must define a **unique** `static const routeName`.
- Register Blocs/Cubits as **lazy singletons** in `get_it`.
- Use `@disposeMethod` to ensure proper disposal.
- Turn on `AutoProvider.enableLogging` to see route changes in development.

---

## 🧾 License

MIT
