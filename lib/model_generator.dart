import 'dart:collection';

import 'package:dart_style/dart_style.dart';
import 'package:json_ast/json_ast.dart' show parse, Settings, Node;
import 'package:json_to_dart/helpers.dart';
import 'package:json_to_dart/string_ext.dart';
import 'package:json_to_dart/syntax.dart';

class DartCode extends WithWarning<String> {
  DartCode(String result, List<Warning> warnings) : super(result, warnings);

  String get code => this.result;
}

/// A Hint is a user type correction.
class Hint {
  final String path;
  final String type;

  Hint(this.path, this.type);
}

class ModelGenerator {
  final String _rootClassName;
  final bool _privateFields;
  List<ClassDefinition> allClasses = <ClassDefinition>[];
  final Map<String, String> sameClassMapping = HashMap<String, String>();
  late List<Hint> hints;

  ModelGenerator(this._rootClassName, [this._privateFields = false, hints]) {
    if (hints != null) {
      this.hints = hints;
    } else {
      this.hints = <Hint>[];
    }
  }

  Hint? _hintForPath(String path) {
    final hint = this
        .hints
        .firstWhere((h) => h.path == path, orElse: () => Hint("", ""));
    if (hint.path == "") {
      return null;
    }
    return hint;
  }

  List<Warning> _generateClassDefinition({
    required String className,
    required dynamic jsonRawDynamicData,
    required String path,
    required Node? astNode,
    String prefix = "",
    String suffix = "",
    bool hasCopyWithFunc = true,
  }) {
    List<Warning> warnings = <Warning>[];
    if (jsonRawDynamicData is List) {
      // if first element is an array, start in the first element.
      final node = navigateNode(astNode, '0');
      _generateClassDefinition(
        className: className,
        jsonRawDynamicData: jsonRawDynamicData[0],
        path: path,
        astNode: node!,
        prefix: prefix,
        suffix: suffix,
        hasCopyWithFunc: hasCopyWithFunc,
      );
    } else {
      final Map<dynamic, dynamic> jsonRawData = jsonRawDynamicData;
      final keys = jsonRawData.keys;
      final classDefinition = ClassDefinition(
        // name: className,
        name: "$prefix$className$suffix",
        privateFields: _privateFields,
        hasCopyWithFunc: hasCopyWithFunc,
        prefix: prefix,
        suffix: suffix,
      );
      keys.forEach((key) {
        TypeDefinition typeDef;
        final hint = _hintForPath('$path/$key');
        final node = navigateNode(astNode, key);
        if (hint != null) {
          typeDef = TypeDefinition(hint.type, astNode: node);
        } else {
          typeDef = TypeDefinition.fromDynamic(jsonRawData[key], node);
        }
        if (typeDef.name == 'Class') {
          typeDef.name = camelCase(key);
          typeDef.name = typeDef.name.padding(
            prefix: prefix,
            suffix: suffix,
          );
          // print("typeDef.name:${typeDef.name}");
        }
        if (typeDef.name == 'List' && typeDef.subtype == 'Null') {
          warnings.add(newEmptyListWarn('$path/$key'));
        }
        if (typeDef.subtype != null && typeDef.subtype == 'Class') {
          typeDef.subtype = camelCase(key);
          // print("typeDef.subtype:${typeDef.subtype}");
          typeDef.subtype = (typeDef.subtype ?? "").padding(
            prefix: prefix,
            suffix: suffix,
          );
          // print("typeDef.subtype2:${typeDef.subtype}");
        }
        if (typeDef.isAmbiguous) {
          warnings.add(newAmbiguousListWarn('$path/$key'));
        }
        classDefinition.addField(key, typeDef);
      });
      final similarClass = allClasses.firstWhere((cd) => cd == classDefinition,
          orElse: () => ClassDefinition(name: ""));
      if (similarClass.name != "") {
        final similarClassName = similarClass.name;
        final currentClassName = classDefinition.name;
        sameClassMapping[currentClassName] = similarClassName;
      } else {
        allClasses.add(classDefinition);
      }
      final dependencies = classDefinition.dependencies;
      dependencies.forEach((dependency) {
        List<Warning> warns = <Warning>[];
        if (dependency.typeDef.name == 'List') {
          // only generate dependency class if the array is not empty
          if (jsonRawData[dependency.name].length > 0) {
            // when list has ambiguous values, take the first one, otherwise merge all objects
            // into a single one
            dynamic toAnalyze;
            if (!dependency.typeDef.isAmbiguous) {
              WithWarning<Map> mergeWithWarning = mergeObjectList(
                  jsonRawData[dependency.name], '$path/${dependency.name}');
              toAnalyze = mergeWithWarning.result;
              warnings.addAll(mergeWithWarning.warnings);
            } else {
              toAnalyze = jsonRawData[dependency.name][0];
            }
            final node = navigateNode(astNode, dependency.name);
            warns = _generateClassDefinition(
              className: dependency.className,
              jsonRawDynamicData: toAnalyze,
              path: '$path/${dependency.name}',
              astNode: node,
              prefix: prefix,
              suffix: suffix,
            );
          }
        } else {
          final node = navigateNode(astNode, dependency.name);
          warns = _generateClassDefinition(
            className: dependency.className,
            jsonRawDynamicData: jsonRawData[dependency.name],
            path: '$path/${dependency.name}',
            astNode: node,
            prefix: prefix,
            suffix: suffix,
          );
        }
        warnings.addAll(warns);
      });
    }
    return warnings;
  }

  /// generateUnsafeDart will generate all classes and append one after another
  /// in a single string. The [rawJson] param is assumed to be a properly
  /// formatted JSON string. The dart code is not validated so invalid dart code
  /// might be returned
  DartCode generateUnsafeDart({
    required String rawJson,
    String classPrefix = "",
    String classSuffix = "",
    bool hasCopyWithFunc = true,
  }) {
    final jsonRawData = decodeJSON(rawJson);
    final astNode = parse(rawJson, Settings());
    List<Warning> warnings = _generateClassDefinition(
      className: _rootClassName,
      jsonRawDynamicData: jsonRawData,
      path: "",
      astNode: astNode,
      prefix: classPrefix,
      suffix: classSuffix,
      hasCopyWithFunc: hasCopyWithFunc,
    );
    // after generating all classes, replace the omited similar classes.
    allClasses.forEach((c) {
      final fieldsKeys = c.fields.keys;
      fieldsKeys.forEach((f) {
        final typeForField = c.fields[f];
        if (typeForField != null) {
          if (sameClassMapping.containsKey(typeForField.name)) {
            c.fields[f]!.name = sameClassMapping[typeForField.name]!;
          }
        }
      });
    });
    return DartCode(allClasses.map((c) => c.toString()).join('\n'), warnings);
  }

  /// generateDartClasses will generate all classes and append one after another
  /// in a single string. The [rawJson] param is assumed to be a properly
  /// formatted JSON string. If the generated dart is invalid it will throw an error.
  DartCode generateDartClasses({
    required String rawJson,
    String classPrefix = "",
    String classSuffix = "",
    bool hasCopyWithFunc = true,
  }) {
    final unsafeDartCode = generateUnsafeDart(
      rawJson: rawJson,
      classPrefix: classPrefix,
      classSuffix: classSuffix,
      hasCopyWithFunc: hasCopyWithFunc,
    );
    final formatter = DartFormatter();
    return DartCode(
        formatter.format(unsafeDartCode.code), unsafeDartCode.warnings);
  }
}
