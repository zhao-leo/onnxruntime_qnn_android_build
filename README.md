# Onnxruntime With Qnn

The onnxruntime doesn't offer pre-built onnxruntime package with qnn for android. Besides,it's document seems confusing and will cause a lot of mistakes even you followed all steps.

So I make the repo to help you build your own onnxruntime-qnn for android.

## How it works
### `libonnxruntime.so`
It's the core dynamic library. With this library and some JNI codes, you can use onnxruntime interface which you are more familiar with to write codes to run the `*.onnx` model.

Here are some key points:
1. Use openjdk-17. (No jdk-21!)
2. Use ANDROID_API=27.(26c is also available)
3. Check if the Qnn library is available.(Public library(Released Quarterly) is more recommended. The newest qnn package which you got from `qpm3-cli` may cause some questions.)

### `onnxruntime.aar`
It's the official java library with more general APIs. The library **may have some issues** because it has not undergone unittests.

Here are some key points:
1. The same requirements with `libonnxruntime.so`.
2. Skip unittests.

Skip unittests is necessary because:
1. The official `CmakeLists.txt` have some bugs.
  For example, it uses the `clang6.0` target but the target has dropped.
  Besides, the unittest need the dynamic library which can not be tested due to `Qualcomm`‘s limitation.(The qnn lib with htp bankend can only run on SoC with HTP, otherwise the lib will throw an error.)
3. The target may also have some problems.
