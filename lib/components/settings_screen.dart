import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _backgroundImagePath;
  bool _isButtonTransparent = false;

    @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
    _loadButtonTransparency();
  }

  Future<void> _loadBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundImagePath = prefs.getString('backgroundImage');
    });
  }

  Future<void> _saveBackgroundImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backgroundImage', path);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      await _saveBackgroundImage(pickedFile.path);
      _loadBackgroundImage();
    }
  }

  Future<void> _removeBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('backgroundImage');
    _loadBackgroundImage();
  }

  Future<void> _loadButtonTransparency() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isButtonTransparent = prefs.getBool('buttonTransparency') ?? false;
    });
  }

  Future<void> _saveButtonTransparency(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('buttonTransparency', value);
    setState(() {
      _isButtonTransparent = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuraciones Generales'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: Text(
                      'Apariencia',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    title: const Text('Establecer imagen de fondo'),
                    leading: const Icon(Icons.image),
                    onTap: _pickImage,
                  ),
                                    if (_backgroundImagePath != null)
                    ListTile(
                      title: const Text('Quitar imagen de fondo'),
                      leading: const Icon(Icons.hide_image),
                      onTap: _removeBackgroundImage,
                    ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Transparencia en botones'),
                    value: _isButtonTransparent,
                    onChanged: _saveButtonTransparency,
                    secondary: const Icon(Icons.opacity),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
