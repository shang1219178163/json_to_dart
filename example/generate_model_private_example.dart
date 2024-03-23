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
  final classGenerator = new ModelGenerator('Sample', true);
  final currentDirectory = dirname(_scriptPath());
  final filePath = normalize(join(currentDirectory, 'sample.json'));
  final jsonRawData = new File(filePath).readAsStringSync();
  DartCode? dartCode = classGenerator.generateDartClasses(rawJson: jsonRawData);
  print(dartCode?.code);
}
