import 'dart:io';

import 'package:easy_nlu/parser/logicalForm.dart';
import 'package:easy_nlu/parser/parser.dart';
import 'package:easy_nlu/trainer/dataset.dart';
import 'package:easy_nlu/trainer/optimizer.dart';

class Model {
  Parser _parser;
  Map<String, double> _weights;

  Model(Parser parser)
      : _parser = parser,
        _weights = parser.weights;

  Parser get parser => _parser;
  Map<String, double> get weights => _weights;

  void loadWeights(String filePath) {
    _weights = _parseText(File(filePath).readAsStringSync());
    parser.weights = _weights;
  }

  Map<String, double> _parseText(String text) {
    Map<String, double> weights = {};

    List<String> lines = text.split("\n");
    for (var line in lines) {
      line = line.trim();
      if (line != null && line.isNotEmpty) {
        List<String> items = line.split("\t");
        assert(items.length == 2, "Malformed input");

        weights[items[0].trim()] = double.parse(items[1].trim());
      }
    }

    return weights;
  }

  String weightsToText() {
    String res = "";

    for (var entry in weights.entries) {
      res += "${entry.key}\t${entry.value}\n";
    }
    return res;
  }

  void train(Dataset d, Optimizer optimizer, int epochs) {
    double loss;
    double maxAcc = 0;
    int count;
    Map<String, double> bestWeights = {};
    for (var i = 0; i < epochs; ++i) {
      loss = 0;
      count = 0;

      optimizer.onEpochStart();

      for (var e in d.shuffle().examples) {
        loss += optimizer.optimize(e);
        count++;
      }
      optimizer.onEpochComplete(count);

      print("Epoch ${i + 1}: Train loss = ${loss / count}");
      double acc = evaluate(d, 0);
      if (acc > maxAcc) {
        maxAcc = acc;
        bestWeights = Map.from(_parser.weights);
      }
    }

    print("Max accuracy: $maxAcc");
    _weights = bestWeights;
    _parser.weights = bestWeights;
  }

  double evaluate(Dataset dataset, int verboseLevel) {
    double acc = 0;
    double accOracle = 0;
    double score = 0;
    int count = 0;

    for (var e in dataset.examples) {
      bool first = true;
      bool correct = false;
      bool firstCorrect = false;

      List<LogicalForm> lfs = _parser.parse(e.input);
      for (var lf in lfs) {
        if (first) {
          score += lf.derivation.score;
          if (lf.match(e.label)) {
            if (first) {
              acc++;
              firstCorrect = true;
            }
            accOracle++;
            correct = true;
            break;
          }
          first = true;
        }
      }

      if (!correct && verboseLevel > 0) {
        print("Failed to parse: ${e.input}");
        print("Predictions:");
        lfs.forEach((x) => print(x));
        print("Target:");
        print(e.label);
        print("");
      } else if (!firstCorrect && verboseLevel > 1) {
        print("Wrong prediction for: ${e.input}");
        print("Prediction");
        print(lfs[0]);
        print("Target:");
        print(e.label);
        print("");
      }
      count++;
    }

    if (count > 0) {
      acc /= count;
      score /= count;
      accOracle /= count;
    }

    if (verboseLevel > 0) {
      print("$count examples");
      print("Average score: $score");
    }

    print("Accuracy: $acc");
    print("Oracle accuracy: $accOracle");

    return acc;
  }
}
