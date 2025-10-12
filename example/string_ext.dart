//
//  StringExt.dart
//  json_to_dart
//
//  Created by shang on 2025/10/12 08:47.
//  Copyright © 2025/10/12 shang. All rights reserved.
//

extension StringExt on String {
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

    final list = split(separator);
    return list.map((e) {
      final index = list.indexOf(e);
      return index == 0 && isUpper == false ? e : e.toCapitalize();
    }).join("");
  }

  String replaceLast(String string, Pattern from, String to) {
    if (from is String) {
      final lastIndex = string.lastIndexOf(from);
      if (lastIndex == -1) return string;

      return string.substring(0, lastIndex) + to + string.substring(lastIndex + from.length);
    } else {
      // 处理正则表达式的情况
      final matches = from.allMatches(string).toList();
      if (matches.isEmpty) return string;

      final lastMatch = matches.last;
      return string.substring(0, lastMatch.start) + to + string.substring(lastMatch.end);
    }
  }
}
