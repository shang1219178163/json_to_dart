//
//  string_ext.dart
//  flutter_templet_project
//
//  Created by shang on 8/3/21 11:41 AM.
//  Copyright © 8/3/21 shang. All rights reserved.
//


extension StringExt on String {
  static bool isEmpty(String? val) {
    return val == null || val.isEmpty;
  }

  static bool isNotEmpty(String? val) {
    return val != null && val.isNotEmpty;
  }

  ///运算符重载
  bool operator >(String val) {
    return compareTo(val) == 1;
  }

  ///运算符重载
  String operator *(int value) {
    var result = '';
    for (var i = 0; i < value; i++) {
      result += this;
    }
    return result;
  }

  /// 移除左边
  String trimLeftChar(String char) {
    var result = this;
    if (result.startsWith(char)) {
      result = result.substring(char.length);
    }
    return result;
  }

  /// 移除右边
  String trimRightChar(String char) {
    var result = this;
    if (result.endsWith(char)) {
      result = result.substring(0, result.length - char.length);
    }
    return result;
  }

  /// 移除两端
  String trimChar(String char) {
    var result = trimLeftChar(char).trimRightChar(char);
    return result;
  }

  String padding({
    String prefix = "",
    String suffix = "",
  }) {
    var result = this;
    if (!result.startsWith(prefix)) {
      result = "$prefix$result";
    }
    if (!result.endsWith(suffix)) {
      result = "$result$suffix";
    }
    return result;
  }

  ///首字母大写
  String toCapitalize() {
    if (length <= 1) {
      return this;
    }
    return "${substring(0, 1).toUpperCase()}${substring(1)}";
  }

  ///驼峰命名法, ["_", "-"].contains(separator)
  String toCamlCase(String separator, {bool isUpper = true}) {
    assert(["_", "-"].contains(separator));
    if (!contains(separator)) {
      return this;
    }

    return split(separator).map((e) {
      final index = e.indexOf(this);
      return index == 0 && isUpper == false ? e : e.toCapitalize();
    }).join("");
  }

  ///反驼峰命名法
  String toUncamlCase([String separator = "_"]) {
    var reg = RegExp(r'[A-Z]');
    return split("").map((e) {
      final i = indexOf(e);
      return e.contains(reg)
          ? "${i == 0 ? "" : separator}${e.toLowerCase()}"
          : e;
    }).join("");
  }

}

// extension StringCryptExt on String{
//   toMd5() {
//     Uint8List content = const Utf8Encoder().convert(this);
//     Digest digest = md5.convert(content);
//     return digest.toString();
//   }
// }
