import 'dart:io';
import 'package:json_to_dart/model_generator.dart';
import "package:path/path.dart" show dirname, join, normalize;


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
  DartCode dartCode = classGenerator.generateDartClasses(jsonRawData,
    classPrefix: "YY", classSuffix: "Model",
  );
  print("\n");
  print(dartCode.code);
}
