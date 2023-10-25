import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:room3d/model/prediction.dart';

Future<void> main() async {
  await dotenv.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const TARGET_SIZE = 300;

  final _picker = ImagePicker();
  final _dio = Dio();
  final _apiURL = dotenv.get('API_URL');

  Uint8List? _currentImage;
  List<Prediction> _predictions = [];

  static Uint8List? _processImage(Uint8List bytes) {
    var image = img.decodeImage(bytes);
    if (image == null) {
      return null;
    }

    image = img.copyResizeCropSquare(image, size: TARGET_SIZE);
    final res = img.encodeJpg(image, quality: 50);

    return res;
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    setState(() => _predictions = []);
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();
    final res = await compute(_processImage, bytes);
    if (res != null) {
      setState(() => _currentImage = res);
    }
  }

  Future<void> _getPrediction({int count = 0}) async {
    if (count > 3) {
      return;
    }
    try {
      final res = await _dio.post(
        '$_apiURL/predict',
        data: _currentImage,
        options: Options(
          contentType: 'application/octet-stream',
        ),
      );
      debugPrint('status code: ${res.statusCode}');
      debugPrint('answer: ${res.data}');

      List<Prediction> pred = (res.data['result'] as List)
          .map((elem) => Prediction.fromMap(elem))
          .toList();

      setState(() => _predictions = pred);
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) {
        await Future.delayed(const Duration(seconds: 1));
        await _getPrediction(count: count + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Take a photo and let the AI guess the room type',
            ),
            _currentImage != null
                ? TextButton(
                    child: const Text('Predict'),
                    onPressed: () => _getPrediction(),
                  )
                : Container(),
            Column(
              children: _predictions
                  .map((pred) =>
                      Text("> label: ${pred.label}  score: ${pred.score}"))
                  .toList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePhoto,
        tooltip: 'Take photo',
        child: const Icon(Icons.camera),
      ),
    );
  }
}
