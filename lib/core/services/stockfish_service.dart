import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class StockfishService {
  Process? _process;
  late StreamController<String> _controller;
  Stream<String> get output => _controller.stream;

  Future<void> startEngine() async {
    _controller = StreamController<String>();

    final byteData = await rootBundle.load('assets/stockfish');

    final tempDir = await getTemporaryDirectory();
    final stockfishFile = File('${tempDir.path}/stockfish');

    await stockfishFile.writeAsBytes(byteData.buffer.asUint8List());

    _process = await Process.start(stockfishFile.path, []);

    _process!.stdout.transform(SystemEncoding().decoder).listen((data) {
      _controller.add(data.trim());
    });

    _process!.stderr.transform(SystemEncoding().decoder).listen((data) {
      print("Stockfish error: $data");
    });
  }

  void sendCommand(String command) {
    _process?.stdin.writeln(command);
    print("Enviado a Stockfish: $command");
  }

  void dispose() {
    _controller.close();
    _process?.kill();
  }
}
