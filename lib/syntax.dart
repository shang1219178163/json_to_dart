import 'package:json_ast/json_ast.dart' show Node;
import 'package:json_to_dart/helpers.dart';
import 'package:json_to_dart/string_ext.dart';

const String emptyListWarn = "list is empty";
const String ambiguousListWarn = "list is ambiguous";
const String ambiguousTypeWarn = "type is ambiguous";

class Warning {
  final String warning;
  final String path;

  Warning(this.warning, this.path);
}

Warning newEmptyListWarn(String path) {
  return new Warning(emptyListWarn, path);
}

Warning newAmbiguousListWarn(String path) {
  return new Warning(ambiguousListWarn, path);
}

Warning newAmbiguousType(String path) {
  return new Warning(ambiguousTypeWarn, path);
}

class WithWarning<T> {
  final T result;
  final List<Warning> warnings;

  WithWarning(this.result, this.warnings);
}

class TypeDefinition {
  String name;
  String? subtype;
  bool isAmbiguous = false;
  bool _isPrimitive = false;

  factory TypeDefinition.fromDynamic(dynamic obj, Node? astNode) {
    bool isAmbiguous = false;
    final type = getTypeName(obj);
    if (type == 'List') {
      List<dynamic> list = obj;
      String elemType;
      if (list.length > 0) {
        elemType = getTypeName(list[0]);
        for (dynamic listVal in list) {
          final typeName = getTypeName(listVal);
          if (elemType != typeName) {
            isAmbiguous = true;
            break;
          }
        }
      } else {
        // when array is empty insert Null just to warn the user
        elemType = "Null";
      }
      return new TypeDefinition(type,
          astNode: astNode, subtype: elemType, isAmbiguous: isAmbiguous);
    }
    return new TypeDefinition(type, astNode: astNode, isAmbiguous: isAmbiguous);
  }

  TypeDefinition(this.name,
      {this.subtype, this.isAmbiguous = false, Node? astNode}) {
    if (subtype == null) {
      _isPrimitive = isPrimitiveType(this.name);
      if (this.name == 'int' && isASTLiteralDouble(astNode)) {
        this.name = 'double';
      }
    } else {
      _isPrimitive = isPrimitiveType('$name<$subtype>');
    }
  }

  bool operator ==(other) {
    if (other is TypeDefinition) {
      TypeDefinition otherTypeDef = other;
      return this.name == otherTypeDef.name &&
          this.subtype == otherTypeDef.subtype &&
          this.isAmbiguous == otherTypeDef.isAmbiguous &&
          this._isPrimitive == otherTypeDef._isPrimitive;
    }
    return false;
  }

  bool get isPrimitive => _isPrimitive;

  bool get isPrimitiveList => _isPrimitive && name == 'List';

  String _buildParseClass(String expression) {
    final properType = subtype != null ? subtype : name;
    return '$properType.fromJson($expression)';
  }

  String _buildToJsonClass(String expression, [bool nullGuard = true]) {
    if (nullGuard) {
      return '$expression!.toJson()';
    }
    return '$expression.toJson()';
  }

  String jsonParseExpression(
    String key,
    bool privateField, {
    String prefix = "",
    String suffix = "",
  }) {
    final jsonKey = "json['$key']";
    final fieldKey =
        fixFieldName(key, typeDef: this, privateField: privateField);
    if (isPrimitive) {
      if (name == "List") {
        // return "$fieldKey = json['$key'].cast<$subtype>();";
        return "$fieldKey = List<$subtype>.from(json['$key'] ?? []);";
      }
      if (name.isNotEmpty) {
        return "$fieldKey = (json['$key'] as $name?);";
      }
      return "$fieldKey = json['$key'];";
    } else if (name == "List" && subtype == "DateTime") {
      return "$fieldKey = json['$key'].map((v) => DateTime.tryParse(v));";
    } else if (name == "DateTime") {
      return "$fieldKey = DateTime.tryParse(json['$key']);";
    } else if (name == 'List') {
      // return "if (json['$key'] != null) {\n\t\t\t$fieldKey = <$subtype>[];\n\t\t\tjson['$key'].forEach((v) { $fieldKey!.add($subtype.fromJson(v)); });\n\t\t}";
      if (!_isPrimitive) {
        if (subtype != "Null") {
          subtype = (subtype ?? "").padding(
            prefix: prefix,
            suffix: suffix,
          );
        }
      }
      return "if (json['$key'] != null) {\n\t\t\tfinal array = (json['$key'] as List).map((e) => $subtype.fromJson(e));\n\t\t\t$fieldKey = List<$subtype>.from(array);\n\t\t}";
    } else {
      // class
      final fromJsonDesc = _buildParseClass(
        jsonKey,
      );
      return "$fieldKey = json['$key'] != null ? ${fromJsonDesc} : null;";
    }
  }

  String toJsonExpression(String key, bool privateField, String mapKey) {
    final fieldKey =
        fixFieldName(key, typeDef: this, privateField: privateField);
    final thisKey = '$fieldKey';
    if (isPrimitive) {
      if (thisKey == mapKey) {
        return "$mapKey['$key'] = this.$thisKey;";
      }
      return "$mapKey['$key'] = $thisKey;";
    } else if (name == 'List') {
      // class list
      return """if ($thisKey != null) {
      $mapKey['$key'] = $thisKey!.map((v) => ${_buildToJsonClass('v', false)}).toList();
    }""";
    } else {
      // class
      return """if ($thisKey != null) {
      $mapKey['$key'] = ${_buildToJsonClass(thisKey)};
    }""";
    }
  }
}

class Dependency {
  String name;
  final TypeDefinition typeDef;

  Dependency(this.name, this.typeDef);

  String get className => camelCase(name);
}

class ClassDefinition {
  ClassDefinition({
    required this.name,
    this.privateFields = false,
    this.prefix = "",
    this.suffix = "",
  });

  final String name;
  final bool privateFields;
  final String prefix;
  final String suffix;

  final Map<String, TypeDefinition> fields = Map<String, TypeDefinition>();

  List<Dependency> get dependencies {
    final dependenciesList = <Dependency>[];
    final keys = fields.keys;
    keys.forEach((k) {
      final f = fields[k];
      if (f != null && !f.isPrimitive) {
        dependenciesList.add(Dependency(k, f));
      }
    });
    return dependenciesList;
  }

  bool operator ==(other) {
    if (other is ClassDefinition) {
      ClassDefinition otherClassDef = other;
      return this.isSubsetOf(otherClassDef) && otherClassDef.isSubsetOf(this);
    }
    return false;
  }

  bool isSubsetOf(ClassDefinition other) {
    final List<String> keys = this.fields.keys.toList();
    final int len = keys.length;
    for (int i = 0; i < len; i++) {
      TypeDefinition? otherTypeDef = other.fields[keys[i]];
      if (otherTypeDef != null) {
        TypeDefinition? typeDef = this.fields[keys[i]];
        if (typeDef != otherTypeDef) {
          return false;
        }
      } else {
        return false;
      }
    }
    return true;
  }

  hasField(TypeDefinition otherField) {
    final key = fields.keys
        .firstWhere((k) => fields[k] == otherField, orElse: () => "");
    return key != "";
  }

  addField(String name, TypeDefinition typeDef) {
    fields[name] = typeDef;
  }

  void _addTypeDef(TypeDefinition typeDef, StringBuffer sb) {
    sb.write('${typeDef.name}');
    if (typeDef.subtype != null) {
      sb.write('<${typeDef.subtype}>');
    }
  }

  String get _fieldList {
    return fields.keys.map((key) {
      final f = fields[key]!;
      final fieldName =
          fixFieldName(key, typeDef: f, privateField: privateFields);
      final sb = StringBuffer();
      sb.write('\t');
      _addTypeDef(f, sb);
      sb.write('? $fieldName;');
      return sb.toString();
    }).join('\n\n');
  }

  String get _gettersSetters {
    return fields.keys.map((key) {
      final f = fields[key]!;
      final publicFieldName =
          fixFieldName(key, typeDef: f, privateField: false);
      final privateFieldName =
          fixFieldName(key, typeDef: f, privateField: true);
      final sb = StringBuffer();
      sb.write('\t');
      _addTypeDef(f, sb);
      sb.write(
          '? get $publicFieldName => $privateFieldName;\n\tset $publicFieldName(');
      _addTypeDef(f, sb);
      sb.write('? $publicFieldName) => $privateFieldName = $publicFieldName;');
      return sb.toString();
    }).join('\n');
  }

  String get _defaultPrivateConstructor {
    final sb = StringBuffer();
    sb.write('\t$name({\n');
    var i = 0;
    var len = fields.keys.length - 1;
    fields.keys.forEach((key) {
      final f = fields[key]!;
      final publicFieldName =
          fixFieldName(key, typeDef: f, privateField: false);
      _addTypeDef(f, sb);
      sb.write('? $publicFieldName \n');
      // if (i != len) {
      //   sb.write(',\n');
      // }
      i++;
    });
    sb.write('}) {\n\n');
    fields.keys.forEach((key) {
      final f = fields[key]!;
      final publicFieldName =
          fixFieldName(key, typeDef: f, privateField: false);
      final privateFieldName =
          fixFieldName(key, typeDef: f, privateField: true);
      sb.write('if ($publicFieldName != null) {\n');
      sb.write('this.$privateFieldName = $publicFieldName;\n');
      sb.write('}\n');
    });
    sb.write('}');
    return sb.toString();
  }

  String get _defaultConstructor {
    final sb = StringBuffer();
    sb.write('\t$name({\n');
    var i = 0;
    // var len = fields.keys.length - 1;
    fields.keys.forEach((key) {
      final f = fields[key]!;
      final fieldName =
          fixFieldName(key, typeDef: f, privateField: privateFields);
      sb.write('this.$fieldName, \n');
      // if (i != len) {
      //   sb.write(', ');
      // }
      i++;
    });
    sb.write('});');
    return sb.toString();
  }

  String get _jsonParseFunc {
    final sb = StringBuffer();
    sb.write('\t$name');
    sb.write('.fromJson(Map<String, dynamic>? json) {\n');
    sb.write('\tif (json == null) {\n\treturn;\n}\n');
    fields.keys.forEach((k) {
      sb.write('\t\t${fields[k]!.jsonParseExpression(
        k,
        privateFields,
        prefix: prefix,
        suffix: suffix,
      )}\n');
    });
    sb.write('\t}');
    return sb.toString();
  }

  String get _jsonGenFunc {
    const mapKey = "map";

    final sb = StringBuffer();
    sb.write(
        '\tMap<String, dynamic> toJson() {\n\t\tfinal $mapKey = <String, dynamic>{};\n');
    fields.keys.forEach((k) {
      sb.write(
          '\t\t${fields[k]!.toJsonExpression(k, privateFields, mapKey)}\n');
    });
    sb.write('\t\treturn $mapKey;\n');
    sb.write('\t}');
    return sb.toString();
  }

  String toString() {
    if (privateFields) {
      return '\nclass $name {\n\n$_defaultPrivateConstructor\n\n$_fieldList\n\n$_gettersSetters\n\n$_jsonParseFunc\n\n$_jsonGenFunc\n}\n';
    } else {
      return '\nclass $name {\n\n$_defaultConstructor\n\n$_fieldList\n\n$_jsonParseFunc\n\n$_jsonGenFunc\n}\n';
    }
  }
}
