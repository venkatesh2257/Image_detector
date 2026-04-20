# image_detector

Flutter image classification app (`Vision Trend`) with local/demo prediction flow.

## Development environment setup (Linux)

### 1) Install Flutter SDK

```bash
mkdir -p "$HOME/sdk"
cd "$HOME/sdk"
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$HOME/sdk/flutter/bin:$PATH"
flutter --version
```

### 2) Install system dependencies for Linux desktop

```bash
sudo apt-get update
sudo apt-get install -y ninja-build libgtk-3-dev g++-14 libstdc++-14-dev
```

### 3) Install project dependencies

```bash
cd /workspace
export PATH="$HOME/sdk/flutter/bin:$PATH"
flutter pub get
```

## Run the application

### Linux desktop (recommended in this repository)

```bash
cd /workspace
export PATH="$HOME/sdk/flutter/bin:$PATH"
flutter run -d linux
```

The app window should open with the title `Vision Trend` and visible `Camera` and `Gallery` buttons.

## Notes

- `tflite_flutter` uses native FFI and does not run on the web target. Use Linux/Android/iOS targets for runtime testing.
- If Flutter doctor reports missing Android SDK, Linux desktop can still run normally after the Linux dependencies above are installed.
