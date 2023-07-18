part of flutter_windows;

typedef DialogFilterMap = Map<String, String>;

abstract class FileDialog {
  final int options;
  final String title;
  final String okButtonLabel;

  FileDialog({
    this.options = FILEOPENDIALOGOPTIONS.FOS_FORCEFILESYSTEM,
    required this.title,
    this.okButtonLabel = "Ok",
  });
}

class OpenFileDialog extends FileDialog {
  final DialogFilterMap fileTypes;
  final String? defaultExtension;
  FileOpenDialog? openDialog;

  OpenFileDialog({
    super.options,
    required super.title,
    super.okButtonLabel,
    required this.fileTypes,
    this.defaultExtension,
  }) {
    int hResult = CoInitializeEx(
        nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    if (SUCCEEDED(hResult)) {
      openDialog = FileOpenDialog.createInstance();
      final pfos = calloc<Uint32>();
      hResult = openDialog!.getOptions(pfos);
      if (!SUCCEEDED(hResult)) {
        throw WindowsException(hResult);
      }

      final options = pfos.value | this.options;
      hResult = openDialog!.setOptions(options);
      if (!SUCCEEDED(hResult)) {
        throw WindowsException(hResult);
      }

      final defaultExtensions = TEXT(defaultExtension ?? "");
      hResult = openDialog!.setDefaultExtension(defaultExtensions);
      if (!SUCCEEDED(hResult)) {
        throw WindowsException(hResult);
      }

      final title = TEXT(this.title);
      hResult = openDialog!.setTitle(title);
      if (!SUCCEEDED(hResult)) {
        throw WindowsException(hResult);
      }

      final okButtonLabel = TEXT(this.okButtonLabel);
      hResult = openDialog!.setOkButtonLabel(okButtonLabel);
      if (!SUCCEEDED(hResult)) {
        throw WindowsException(hResult);
      }

      assert(fileTypes.isNotEmpty);
      final rgSpec = calloc<COMDLG_FILTERSPEC>(fileTypes.length);
      for (int i = 0; i < fileTypes.length; i++) {
        rgSpec[i]
          ..pszName = TEXT(fileTypes.keys.elementAt(i))
          ..pszSpec = TEXT(fileTypes.values.elementAt(i));
      }
      hResult = openDialog!.setFileTypes(fileTypes.length, rgSpec);
      if (!SUCCEEDED(hResult)) {
        throw WindowsException(hResult);
      }

      free(rgSpec);
      free(pfos);
    }
  }

  Future<String?> show() {
    final completer = Completer<String?>();

    int hr = openDialog!.show(NULL);
    if (!SUCCEEDED(hr)) {
      if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
        debugPrint('\n[flutter_windows] Dialog cancelled');
      }
    } else {
      final ppsi = calloc<COMObject>();
      hr = openDialog!.getResult(ppsi.cast());
      if (SUCCEEDED(hr)) {
        final item = IShellItem(ppsi);
        final pathPtr = calloc<PWSTR>();
        hr = item.getDisplayName(SIGDN.SIGDN_FILESYSPATH, pathPtr);

        if (SUCCEEDED(hr)) {
          // MAX_PATH may truncate early if long filename support is enabled
          final path = pathPtr.value.toDartString();

          completer.complete(path);
        }
      }
    }

    return completer.future;
  }
}

class SaveFileDialog extends FileDialog {
  SaveFileDialog(
      {required super.options, required super.title, super.okButtonLabel});
}
