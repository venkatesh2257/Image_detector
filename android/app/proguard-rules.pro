# TensorFlow Lite (tflite_flutter) — CPU inference only; GPU delegate jars are optional.
# R8 release builds fail without these because GpuDelegate references classes
# not on the classpath when GPU support is not packaged.
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
