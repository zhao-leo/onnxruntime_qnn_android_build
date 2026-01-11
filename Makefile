# 环境变量配置
# QNN_VERSION can be checked on https://qpm.qualcomm.com/#/main/tools/details/Qualcomm_AI_Runtime_SDK
# Note that not all versions can be used because Qualcomm uses different strategies
# for community edition(often later than commercial) and commercial version.
#
# Onnxruntime version, later will be used to checkout the onnxruntime repo
#
# Android HOME
#
# NDK version(later will build ndk path with $ANDROID_HOME/ndk/$NDK_VERSION)
#
# JDK Version == 17

# 用户变量设置
QNN_VERSION?=2.40.0.251030
ORT_VERSION?=1.23.2
ANDROID_HOME?=/home/april/Android/Sdk
NDK_VERSION?=27.0.12077973
ANDROID_API?=27

# 定义常量
QNN_URL := https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/$(QNN_VERSION)/v$(QNN_VERSION).zip
ROOT_DIR := $(shell pwd)
TEMP_DIR := $(ROOT_DIR)/flat_pack
TEMP_HEADERS := $(TEMP_DIR)/headers
TEMP_JNI_LIBS := $(TEMP_DIR)/jniLibs/arm64-v8a
BUILD_DIR := build/android/arm64-v8a
ORT_SRC_DIR := $(ROOT_DIR)/onnxruntime
QNN_SDK_DIR := $(ROOT_DIR)/qnn_sdk
QNN_ZIP := $(ROOT_DIR)/qnn_sdk.zip

# 克隆 ONNX Runtime 仓库
.PHONY: onnxruntime
onnxruntime:
	@if [ ! -d "$(ORT_SRC_DIR)" ]; then \
		echo "Cloning ONNX Runtime v$(ORT_VERSION)"; \
		git clone --branch v$(ORT_VERSION) --depth 1 https://github.com/microsoft/onnxruntime.git; \
		cd onnxruntime && \
		git apply ../patchs/onnxruntime_unittests.patch; \
	else \
		echo "ONNX Runtime directory already exists"; \
	fi

# 下载并解压 QNN SDK
.PHONY: qnn_sdk
qnn_sdk:
	@if [ ! -d "$(QNN_SDK_DIR)" ]; then \
		echo "Downloading QNN SDK v$(QNN_VERSION)"; \
		wget -O $(QNN_ZIP) "$(QNN_URL)"; \
		echo "Extracting QNN SDK"; \
		unzip $(QNN_ZIP) -d $(QNN_SDK_DIR); \
		rm $(QNN_ZIP); \
	else \
		echo "QNN SDK directory already exists"; \
	fi

# 构建 ONNX Runtime
.PHONY: build
build: onnxruntime qnn_sdk
	@echo "Building ONNX Runtime for Android arm64-v8a"
	@echo "Using environment:"
	@echo "   ORT_VERSION: $(ORT_VERSION)"
	@echo "   QNN_VERSION: $(QNN_VERSION)"
	@echo "  ANDROID_HOME: $(ANDROID_HOME)"
	@echo "   NDK_VERSION: $(NDK_VERSION)"
	@echo "   ANDROID_API: $(ANDROID_API)"
	@$(JAVA_HOME)/bin/javac -version 2>&1 | grep -q "17\." && \
	 echo "     JAVA_HOME: $(JAVA_HOME)" || \
	 { \
		echo "No Java 17 installed, please install Java 17 and set JAVA_HOME then run 'make build'"; \
		echo "Current java detected: $(shell $(JAVA_HOME)/bin/javac -version)"; \
		exit 1; \
	 }
	@cd $(ORT_SRC_DIR) && \
	./build.sh \
		--android \
		--android_sdk_path $(ANDROID_HOME) \
		--android_ndk_path $(ANDROID_HOME)/ndk/$(NDK_VERSION) \
		--android_abi arm64-v8a \
		--android_api $(ANDROID_API) \
		--cmake_generator Ninja \
		--use_qnn static_lib \
		--qnn_home $(QNN_SDK_DIR)/qairt/$(QNN_VERSION) \
		--config Release \
		--parallel \
		--skip_tests \
		--build_shared_lib \
		--build_dir $(BUILD_DIR) \
		--build_java

# 将产物提取
.PHONY: package
package:
	@echo "Extracting build artifacts"
	@mkdir -p $(TEMP_DIR)
	@mkdir -p "$(TEMP_HEADERS)"
	@mkdir -p "$(TEMP_JNI_LIBS)"
	@cp "$(ORT_SRC_DIR)/$(BUILD_DIR)/Release/libonnxruntime.so" "$(TEMP_JNI_LIBS)/libonnxruntime.so"
	@cp -r "$(ORT_SRC_DIR)/include/onnxruntime" "$(TEMP_HEADERS)/onnxruntime"
	@cp -r "$(QNN_SDK_DIR)/qairt/$(QNN_VERSION)/include/QNN" "$(TEMP_HEADERS)/QNN"
	@cp "$(QNN_SDK_DIR)/qairt/$(QNN_VERSION)/lib/aarch64-android/"* "$(TEMP_JNI_LIBS)/" 2>/dev/null
	@cp -r "$(ORT_SRC_DIR)/$(BUILD_DIR)/Release/java/build/android/outputs/aar/onnxruntime-release.aar" "$(TEMP_DIR)/ai.onnxruntime.qnn.aar"
	@tar -czvf "ort@$(ORT_VERSION)_arch@armv8a_backend@qnn_$(QNN_VERSION).tar.gz" -C $(TEMP_DIR) .
	@rm -rf $(TEMP_DIR)

# 清理构建文件
.PHONY: clean
clean:
	@echo "Cleaning build files"
	@rm -rf $(ORT_SRC_DIR)/$(BUILD_DIR)

# 完全清理（包括下载的文件）
.PHONY: distclean
distclean: clean
	@echo "Cleaning all downloaded files"
	@rm -rf $(ORT_SRC_DIR)
	@rm -rf $(QNN_SDK_DIR)
	@rm -f $(QNN_ZIP)

# 显示帮助信息
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  help        - Show this help message (default target)"
	@echo "  build       - Build ONNX Runtime with QNN support [auto-deps: onnxruntime, qnn_sdk]"
	@echo "  package     - Extract the build artifacts"
	@echo "  distclean   - Clean all downloaded files and build files [auto-deps: clean]"
	@echo "  onnxruntime - Clone ONNX Runtime repository"
	@echo "  qnn_sdk     - Download and extract QNN SDK"
	@echo "  clean       - Clean build files"

# 默认目标
.DEFAULT_GOAL := help
