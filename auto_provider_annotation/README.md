# auto_provider_annotation

`auto_provider_annotation` defines the `@AutoProvid()` annotation that powers the Auto Provider toolchain. Annotating a screen with `@AutoProvid()` lets the `auto_provider_generator` package discover which Bloc/Cubit dependencies belong to that screen so it can create the `lib/core/router/auto_provider.dart` file for you.

## Features

- Tiny, dependency-free annotation package that you can ship with your app code.
- Express the Bloc/Cubit classes that a screen depends on in a single place.
- Works with the generator to auto-wire providers, navigator observer logging, and lazy singleton cleanup per route.

## Installation

Add the annotation package to any target package that declares annotated widgets:

```yaml
dependencies:
  auto_provider_annotation:
```

If you also run the generator in the same package, add `auto_provider_generator` and `build_runner` to your `dev_dependencies`.

## Usage

Annotate every screen that should be auto-wired:

```dart
import 'package:auto_provider_annotation/auto_provider_annotation.dart';

@AutoProvid([HomeCubit, ThemeCubit])
class HomeScreen extends StatelessWidget {
  static const routeName = '/home';

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

- The optional list passed to `@AutoProvid()` is converted to `BlocProvider`/`MultiBlocProvider` widgets when the generator builds routes.
- Expose a `static const routeName` on each annotated class so the generator can map routes to dependencies.

## Generated output

After running `dart run build_runner build`, the generator emits `lib/core/router/auto_provider.dart`. Use it inside `MaterialApp`:

```dart
MaterialApp(
  navigatorKey: AutoProvider.navigatorKey,
  onGenerateRoute: AutoProvider.onGenerateRoute,
  navigatorObservers: [AutoProvider.observer],
);
```

## Additional information

- Contributions and issues: open a ticket in the [auto_provider repository](https://github.com/mohamadalghanem474/auto_provider).
- The annotation package intentionally stays lightweight—any logic changes go in the generator so your app’s runtime dependencies remain minimal.
