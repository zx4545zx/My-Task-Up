import 'package:file_picker/file_picker.dart';

import 'file_picker_web_options_stub.dart'
    if (dart.library.js_interop) 'file_picker_web_options_browser.dart'
    as browser;

WebOptions get backupPickerWebOptions => browser.backupPickerWebOptions;
