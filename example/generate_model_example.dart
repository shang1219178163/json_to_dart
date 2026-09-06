import 'dart:io';

import 'package:json_to_dart/model_generator.dart';
import "package:path/path.dart" show dirname, join, normalize;

import 'string_ext.dart';

String _scriptPath() {
  var script = Platform.script.toString();
  if (script.startsWith("file://")) {
    script = script.substring(7);
  } else {
    final idx = script.indexOf("file:/");
    script = script.substring(idx + 5);
  }
  return script;
}

main() {
  var rootClassName = 'Sample';
  var jsonFile = 'sample.json';

  // rootClassName = 'AppDetail';
  // jsonFile = 'appInfo.json';

  final classGenerator = ModelGenerator(rootClassName);
  final currentDirectory = dirname(_scriptPath());
  final filePath = normalize(join(currentDirectory, jsonFile));
  print("currentDirectory: $currentDirectory");
  print("filePath: $filePath");
  final jsonRawData = File(filePath).readAsStringSync();
  final dartCode = classGenerator.generateDartClasses(
      rawJson: jsonRawData,
      classPrefix: "YY",
      classSuffix: "Model",
      hasCopyWithFunc: true,
      onMore: (body, classes) {
        final copyRights = """
//  ${classes.first.name}.dart
//
//  Created by JsonToModel on 2025/10/12 10:03.
//
""";

        var result = [
          copyRights,
          "import 'package:equatable/equatable.dart';",
          body,
        ].join("\n");
        return result;
      },
      onConvert: (body, cls) {
        var result = body.replaceFirst("class ${cls.name}", "class ${cls.name} extends Equatable");

        final from = "${cls.name}.fromJson(Map<String, dynamic> json) {";
        final to = """
   @override
  List<Object> get props => ${cls.fields.keys.map(
                  (e) => e.toCamlCase("_", isUpper: false),
                ).toList()}.where((e) => e
   != null)
  .whereType<Object>().toList();
 
 $from
  """;

        result = result.replaceFirst(from, to);
        return result;
      });
  print("\n");
  print(dartCode.code);
}
