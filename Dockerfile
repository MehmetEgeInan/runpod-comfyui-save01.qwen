# Runpod için Optimize Qwen Image Dockerfile (Tam Sürüm)
# Ubuntu 22.04 + CUDA 12.1 (PyTorch 2.4.1 uyumlu)
# Not: CUDA 12.8 henüz mevcut değil, en güncel kararlı sürüm kullanılıyor
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# Build argümanları - Ampere, Hopper ve Blackwell mimarileri destekli
ARG TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;10.0"
ARG MAX_JOBS=4
ARG DEBIAN_FRONTEND=noninteractive

# Ortam değişkenleri
ENV TZ=UTC
ENV PYTHONUNBUFFERED=1
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}
ENV MAX_JOBS=${MAX_JOBS}
ENV RUN_MODE=ui
ENV QWEN_REPO_ID=Qwen/Qwen-Image
ENV QWEN_FILENAME=qwen_image_distill_full_bf16.safetensors

# ============ KATMAN 1: Sistem Bağımlılıkları ============
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-dev \
    python3-pip \
    python3.10-venv \
    git \
    wget \
    curl \
    unzip \
    build-essential \
    ninja-build \
    cmake \
    pkg-config \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    ffmpeg \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ============ KATMAN 2: Python Temel Kurulum ============
RUN python3 -m pip install --no-cache-dir --upgrade pip wheel setuptools packaging

# ============ KATMAN 3: PyTorch (CUDA 12.1) ============
RUN pip install --no-cache-dir \
    torch==2.4.1+cu121 \
    torchvision==0.19.1+cu121 \
    torchaudio==2.4.1+cu121 \
    --index-url https://download.pytorch.org/whl/cu121

# ============ KATMAN 4: Temel ML Kütüphaneleri ============
RUN pip install --no-cache-dir \
    "numpy>=1.24.0" \
    "pillow>=10.0.0" \
    "opencv-python-headless>=4.8.0" \
    "requests>=2.30.0" \
    "tqdm>=4.65.0" \
    "psutil>=5.9.0" \
    "pyyaml>=6.0.0"

# ============ KATMAN 5: Performans Optimizasyonları ============
# Xformers: https://github.com/facebookresearch/xformers
# Flash Attention 3: https://github.com/Dao-AILab/flash-attention
RUN pip install --no-cache-dir \
    "xformers==0.0.28.post1" \
    "flash-attn>=2.5.0" --no-build-isolation \
    ninja \
    packaging

# ============ KATMAN 6: Transformer ve Diğer Kütüphaneler ============
RUN pip install --no-cache-dir \
    "transformers>=4.35.0" \
    "diffusers>=0.25.0" \
    "accelerate>=0.25.0" \
    "safetensors>=0.4.0" \
    "omegaconf>=2.3.0" \
    "einops>=0.7.0" \
    "kornia>=0.7.0" \
    "ftfy>=6.1.0" \
    "sentencepiece>=0.1.99" \
    "huggingface_hub>=0.23.0" \
    "runpod>=1.5.0"

# ============ KATMAN 6.1: GGUF ve Diffusers Ek Kurulum ============
RUN pip install --no-cache-dir gguf --upgrade diffusers

# ============ KATMAN 7: ComfyUI Kurulumu ============
WORKDIR /workspace
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git
WORKDIR /workspace/ComfyUI

# Tüm gereksinimleri yükle
RUN if [ -f requirements.txt ]; then \
        pip install --no-cache-dir -r requirements.txt; \
    else \
        pip install --no-cache-dir \
            "torch>=2.0.0" \
            "torchvision" \
            "torchaudio" \
            "Pillow" \
            "numpy" \
            "opencv-python" \
            "requests" \
            "tqdm" \
            "psutil" \
            "pyyaml"; \
    fi

# ============ KATMAN 8: AWS S3 Kütüphaneleri ============
RUN pip install --no-cache-dir \
    "boto3>=1.34.0" \
    "botocore>=1.34.0" \
    "awscli>=1.32.0"

# ============ KATMAN 9: Custom Nodes Dizini Oluşturma ============
RUN mkdir -p /workspace/ComfyUI/custom_nodes

# ============ KATMAN 10: Tüm Custom Node'ları Yükleme ============
WORKDIR /workspace/ComfyUI/custom_nodes

# ComfyUI Manager (Gereksinim: https://github.com/Comfy-Org/ComfyUI-Manager)
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git \
    && rm -rf /workspace/ComfyUI/custom_nodes/ComfyUI-Manager/.git

# Video Helper Suite
RUN git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    && rm -rf /workspace/ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite/.git

# Diğer node'lar
RUN git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git \
    && rm -rf /workspace/ComfyUI/custom_nodes/ComfyUI-KJNodes/.git
RUN git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git \
    && rm -rf /workspace/ComfyUI/custom_nodes/ComfyUI-WanVideoWrapper/.git

# Image-to-Image (I2I) için gerekli node'lar
RUN git clone --depth 1 https://github.com/Fannovel16/comfyui_controlnet_aux.git \
    && rm -rf /workspace/ComfyUI/custom_nodes/comfyui_controlnet_aux/.git
RUN git clone --depth 1 https://github.com/WASasquatch/was-node-suite-comfyui.git \
    && rm -rf /workspace/ComfyUI/custom_nodes/was-node-suite-comfyui/.git
RUN git clone --depth 1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git \
    && rm -rf /workspace/ComfyUI/custom_nodes/ComfyUI-Custom-Scripts/.git

# ============ KATMAN 11: Video/Audio Kütüphaneleri ============
RUN pip install --no-cache-dir \
    "imageio>=2.30.0" \
    "imageio-ffmpeg>=0.4.8" \
    "scikit-image>=0.20.0" \
    "moviepy>=1.0.3" \
    "av>=10.0.0" \
    "decord>=0.6.0" \
    "librosa>=0.10.0" \
    "soundfile>=0.12.0" \
    "aiohttp>=3.8.0" \
    "websockets>=11.0.0" \
    "scipy>=1.10.0" \
    "matplotlib>=3.7.0"

# ============ KATMAN 11.1: Image-to-Image (I2I) Kütüphaneleri ============
RUN pip install --no-cache-dir \
    "controlnet-aux>=0.0.7" \
    "mediapipe>=0.10.0" \
    "insightface>=0.7.3" \
    "onnxruntime-gpu>=1.16.0" \
    "rembg>=2.0.50" \
    "segment-anything>=1.0" \
    "ultralytics>=8.0.0" \
    "timm>=0.9.0" \
    "tensorboard>=2.14.0"

# ============ KATMAN 12: Model Dizinleri Oluşturma ============
# Model dosyaları volume mount ile kullanılacak, image'a gömülmeyecek
RUN mkdir -p /workspace/ComfyUI/models/checkpoints
RUN mkdir -p /workspace/ComfyUI/models/vae
RUN mkdir -p /workspace/ComfyUI/models/loras
RUN mkdir -p /workspace/ComfyUI/models/embeddings
RUN mkdir -p /workspace/ComfyUI/models/hypernetworks
RUN mkdir -p /workspace/ComfyUI/models/unet

# ============ KATMAN 13: Sistem Doğrulama Scripti ============
RUN printf '%s\n' \
  '#!/bin/bash' \
  'set -e' \
  'echo "=== System Verification ==="' \
  'python3 -c '\''import torch; print("PyTorch:", torch.__version__); print("CUDA:", torch.version.cuda); print("GPU:", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "N/A")'\''' \
  'echo "=== Model Directory Check ==="' \
  'if [ -d "/workspace/ComfyUI/models/checkpoints" ] ; then' \
  '  echo "✅ Model directory exists"' \
  '  echo "📁 Models should be mounted via volume"' \
  'else' \
  '  echo "❌ Model directory missing"' \
  'fi' \
  'echo "=== Custom Nodes ==="' \
  'ls /workspace/ComfyUI/custom_nodes || true' \
  'echo "=== Verification Complete ==="' \
  > /workspace/verify.sh \
  && chmod +x /workspace/verify.sh

# ============ KATMAN 14: Başlatma Scripti ============
RUN echo '#!/bin/bash\n\
echo "🚀 ComfyUI RunPod S3 Integration - Production Ready"\n\
echo "============================================"\n\
/workspace/verify.sh\n\
echo "============================================"\n\
echo "Starting server..."\n\
exec python3 main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --enable-cors-header \
    --disable-auto-launch \
    "$@"' > /workspace/start.sh && chmod +x /workspace/start.sh

# ============ KATMAN 15: Serverless Dosyaları ============
WORKDIR /workspace
COPY serverless/handler.py /workspace/handler.py
COPY serverless/entrypoint.sh /workspace/entrypoint.sh
RUN chmod +x /workspace/entrypoint.sh

# ============ KATMAN 16: S3 Uploader Dosyalarını Kopyalama ============
COPY s3UploaderForLocals/ /workspace/s3UploaderForLocals/

# ============ KATMAN 17: GGUF ve py-gguf Kurulumu ve Testi ============
RUN pip install --no-cache-dir gguf
RUN python3 -c "import gguf; print('gguf başarıyla yüklendi')"
RUN pip install --no-cache-dir onnx
RUN pip install --no-cache-dir onnxruntime

# ============ KATMAN 18: S3 Bağlantı Testi ============
RUN python3 -c "from s3UploaderForLocals import S3Uploader; uploader = S3Uploader(); print('S3 Uploader test:', uploader.test_connection())"

# ============ KATMAN 19: Boyut Optimizasyonu ============
# Gereksiz dosyaları temizle
RUN find /workspace -name "*.pyc" -delete && \
    find /workspace -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true && \
    rm -rf /root/.cache && \
    rm -rf /tmp/* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ============ SON AYARLAR ============
EXPOSE 8188
WORKDIR /workspace/ComfyUI
CMD ["/workspace/entrypoint.sh"]

# Build bilgisi
RUN echo "ComfyUI RunPod S3 Integration - Full Production Build - $(date)" > /workspace/build_info.txt