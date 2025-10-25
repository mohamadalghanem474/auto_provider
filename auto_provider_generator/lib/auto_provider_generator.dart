library AutoProviderGenerator;

import 'package:auto_provider_annotation/auto_provider_annotation.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';

Builder autoProviderBuilder(BuilderOptions options) => _AutoProviderBuilder();

class _AutoProviderBuilder implements Builder {
  @override
  final buildExtensions = const {
    r'$lib$': ['core/router/auto_provider.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    final packageName = buildStep.inputId.package;
    final assets = await buildStep.findAssets(Glob('lib/**.dart')).toList();

    final blocClasses = <String, String>{};
    final imports = <String>{};
    final depToRoutes = <String, Set<String>>{};
    final screenDeps = <String, List<String>>{};

    // ----------------------------------------
    // Pass 1: find all Cubit/Bloc classes
    // ----------------------------------------
    for (final asset in assets) {
      if (asset.path.contains('lib/core/router/auto_provider.dart')) continue;
      final lib = await resolver.libraryFor(asset);

      for (final element in lib.exportNamespace.definedNames2.values) {
        if (element is! ClassElement) continue;
        final superName =
            element.supertype?.getDisplayString(withNullability: false) ?? '';
        if (superName.contains('Cubit') ||
            superName.contains('Bloc') ||
            superName.contains('Hydrated')) {
          final importPath =
              asset.path.replaceFirst('lib/', 'package:$packageName/');
          blocClasses[element.name!] = importPath;
        }
      }
    }

    // ----------------------------------------
    // Pass 2: find @AutoProvider annotated widgets
    // ----------------------------------------
    for (final asset in assets) {
      if (asset.path.contains('lib/core/router/auto_provider.dart')) continue;
      final lib = await resolver.libraryFor(asset);

      bool hasAnnotatedScreen = false;
      for (final element in lib.exportNamespace.definedNames2.values) {
        if (element is! ClassElement) continue;

        final annotations =
            const TypeChecker.typeNamed(AutoProvid).annotationsOf(element);
        if (annotations.isEmpty) continue;

        hasAnnotatedScreen = true;
        final annotation = ConstantReader(annotations.first);
        final className = element.name!;

        final deps = annotation.read('blocProviders').listValue;
        final depNames = deps
            .map((d) =>
                d.toTypeValue()?.getDisplayString(withNullability: false) ?? '')
            .where((n) => n.isNotEmpty)
            .toList();
        screenDeps[className] = depNames;

        String? routeName;
        for (final field in element.fields) {
          if (field.isStatic && field.name == 'routeName') {
            final val = field.computeConstantValue()?.toStringValue();
            routeName = val;
            break;
          }
        }
        if (routeName == null) continue;

        for (final dep in depNames) {
          depToRoutes
              .putIfAbsent(dep, () => <String>{})
              .add('$className.routeName');
        }
      }

      if (hasAnnotatedScreen) {
        final importPath =
            asset.path.replaceFirst('lib/', 'package:$packageName/');
        imports.add("import '$importPath';");
      }
    }

    // ----------------------------------------
    // Build sets
    // ----------------------------------------
    final depSets = StringBuffer();
    for (final entry in depToRoutes.entries) {
      final depName = entry.key;
      final setName = '_${_camel(depName)}';
      depSets.writeln('  final $setName = {');
      for (final route in entry.value) {
        depSets.writeln('    $route,');
      }
      depSets.writeln('  };');
    }

    // ----------------------------------------
    // Used bloc imports
    // ----------------------------------------
    final usedBlocImports = <String>{};
    for (final dep in depToRoutes.keys) {
      final importPath = blocClasses[dep];
      if (importPath != null) usedBlocImports.add("import '$importPath';");
    }

    // ----------------------------------------
    // Route builders
    // ----------------------------------------
    final routeBuilders = StringBuffer();
    for (final entry in screenDeps.entries) {
      final className = entry.key;
      final deps = entry.value;
      routeBuilders.writeln('      case $className.routeName:');
      if (deps.isEmpty) {
        routeBuilders.writeln('        return const $className();');
      } else if (deps.length == 1) {
        routeBuilders.writeln('        return BlocProvider.value(');
        routeBuilders.writeln('          value: sl<${deps.first}>(),');
        routeBuilders.writeln('          child: const $className(),');
        routeBuilders.writeln('        );');
      } else {
        routeBuilders.writeln('        return MultiBlocProvider(');
        routeBuilders.writeln('          providers: [');
        for (final dep in deps) {
          routeBuilders
              .writeln('            BlocProvider.value(value: sl<$dep>()),');
        }
        routeBuilders.writeln('          ],');
        routeBuilders.writeln('          child: const $className(),');
        routeBuilders.writeln('        );');
      }
    }

    // ----------------------------------------
    // Final output buffer
    // ----------------------------------------
    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln('// ignore_for_file: type=lint')
      ..writeln()
      ..writeln("import 'dart:developer' as developer;")
      ..writeln("import 'package:flutter/foundation.dart';")
      ..writeln("import 'package:flutter/material.dart';")
      ..writeln("import 'package:flutter_bloc/flutter_bloc.dart';")
      ..writeln("import 'package:$packageName/core/injectable/get_it.dart';")
      ..writeln(usedBlocImports.join('\n'))
      ..writeln(imports.join('\n'))
      ..writeln()
      ..writeln('class AutoProvider extends NavigatorObserver {')
      ..writeln('  AutoProvider._internal();')
      ..writeln('  static final AutoProvider _instance = AutoProvider._internal();')
      ..writeln()
      ..writeln('  /// Required Add Observer On MaterialApp To Use AutoProvider')
      ..writeln('  static AutoProvider get observer => _instance;')
      ..writeln()
      ..writeln('  /// Global navigator key for accessing navigator outside BuildContext')
      ..writeln('  static final navigatorKey = GlobalKey<NavigatorState>();')
      ..writeln()
      ..writeln('  /// Tracks the current active route name')
      ..writeln('  static String? currentLocation;')
      ..writeln()
      ..writeln('  /// Enable to print route transitions in debug console')
      ..writeln('  static bool enableLogging = true;')
      ..writeln()
      ..write(depSets.toString())
      ..writeln()
      ..writeln('  /// Handles dependency cleanup based on route transitions')
      ..writeln('  void _handleRouteChange(Route<dynamic>? route) {')
      ..writeln('    final name = route?.settings.name;')
      ..writeln('    if (name == null) return;')
      ..writeln('    currentLocation = name;');

    for (final dep in depToRoutes.keys) {
      final setName = '_${_camel(dep)}';
      buffer
        ..writeln('    if (sl.checkLazySingletonInstanceExists<$dep>()) {')
        ..writeln('      if (!$setName.contains(name)) {')
        ..writeln('        sl.resetLazySingleton<$dep>();')
        ..writeln('      }')
        ..writeln('    }');
    }

    buffer
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Called when a new route is pushed onto the navigator.')
      ..writeln('  @override')
      ..writeln('  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {')
      ..writeln('    _handleRouteChange(route);')
      ..writeln('    if (kDebugMode && enableLogging) {')
      ..writeln('      developer.log(')
      ..writeln('        name: "✈️ PUSH",')
      ..writeln('        "\${previousRoute?.settings.name != null ? \'\${previousRoute?.settings.name} ➡️ \' : ""} \${route.settings.name}",')
      ..writeln('      );')
      ..writeln('    }')
      ..writeln('    super.didPush(route, previousRoute);')
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Called when a route is popped off the navigator.')
      ..writeln('  @override')
      ..writeln('  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {')
      ..writeln('    _handleRouteChange(previousRoute);')
      ..writeln('    if (kDebugMode && enableLogging)')
      ..writeln('      developer.log(name: "✈️ POP", "\${previousRoute?.settings.name}");')
      ..writeln('    super.didPop(route, previousRoute);')
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Called when a route is replaced with a new one.')
      ..writeln('  @override')
      ..writeln('  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {')
      ..writeln('    _handleRouteChange(newRoute);')
      ..writeln('    if (kDebugMode && enableLogging) {')
      ..writeln('      developer.log(')
      ..writeln('        name: "✈️ REPLACE",')
      ..writeln('        "\${oldRoute?.settings.name != null ? \'\${oldRoute?.settings.name} 🔄 \' : ""} \${newRoute?.settings.name}",')
      ..writeln('      );')
      ..writeln('    }')
      ..writeln('    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);')
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Called when a route is removed from the navigator.')
      ..writeln('  @override')
      ..writeln('  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {')
      ..writeln('    _handleRouteChange(previousRoute);')
      ..writeln('    if (kDebugMode && enableLogging)')
      ..writeln('      developer.log(name: "✈️ REMOVE", \'🔴 \${route.settings.name}\');')
      ..writeln('    super.didRemove(route, previousRoute);')
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Find The Screen By RouteName')
      ..writeln('  static Widget find(String? name) {')
      ..writeln('    switch (name) {')
      ..write(routeBuilders.toString())
      ..writeln('      default:')
      ..writeln(
          "        return Scaffold(body: Center(child: Text('No Annutation @AutoProvider() on route \$name')));")
      ..writeln('    }')
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Default OnGenerateRoute You Can Customize It In Other File')
      ..writeln('  static Route<dynamic> onGenerateRoute(RouteSettings settings) {')
      ..writeln(
          '    return MaterialPageRoute(settings: settings, builder: (_) => find(settings.name));')
      ..writeln('  }')
      ..writeln('}');

    await buildStep.writeAsString(
      AssetId(packageName, 'lib/core/router/auto_provider.dart'),
      buffer.toString(),
    );
  }

  String _camel(String type) {
    if (type.isEmpty) return type;
    return type[0].toLowerCase() + type.substring(1);
  }
}
