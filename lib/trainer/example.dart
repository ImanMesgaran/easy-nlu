import 'dart:convert';

class Example {
  String input;
  Map<String, Object>? label;

  Example(this.input, String json) {
    input = input;
    final _label = Map<String, Object>.from(jsonDecode(json));
    label = Map<String, Object>.from(jsonDecode(json));
    //label = jsonDecode(json);
  }
}
