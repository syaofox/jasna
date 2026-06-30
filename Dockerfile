# syntax=docker/dockerfile:1.4
# Single-stage build: everything in nvidia/cuda:13.0.0-devel-ubuntu24.04.
# Larger image than a multi-stage split, but avoids CUDA library symbol mismatches
# that vali (built from git) hits when staged against the runtime image.
FROM nvidia/cuda:13.0.0-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# ---------------------------------------------------------------------------
# System packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswresample-dev \
    libswscale-dev \
    # GUI / OpenCV / X11 / Tcl
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    libx11-6 \
    libxcb1 \
    libxau6 \
    libxdmcp6 \
    libxext6 \
    libxrender1 \
    libsm6 \
    libxkbcommon0 \
    libtcl8.6 \
    libtk8.6 \
    # mkvmerge
    mkvtoolnix \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Python + uv
# ---------------------------------------------------------------------------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

ENV UV_PYTHON_INSTALL_DIR=/opt/python
RUN --mount=type=cache,target=/root/.cache/uv \
    uv python install 3.13

ENV VIRTUAL_ENV=/opt/venv
RUN uv venv --python 3.13 $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Build deps (old setuptools for pkg_resources used by vali's setup.py)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install "setuptools<82" wheel scikit-build cmake ninja

# ---------------------------------------------------------------------------
# Python dependencies
# ---------------------------------------------------------------------------
COPY pyproject.toml README.md ./

# 1. PyTorch with CUDA 13.0
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install \
    --index-url https://download.pytorch.org/whl/cu130 \
    torch==2.12.0+cu130 \
    torchvision==0.27.0+cu130

# 2. TensorRT + torch-tensorrt
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install \
    --extra-index-url https://pypi.nvidia.com/ \
    tensorrt==10.16.1.11 \
    torch-tensorrt==2.12.0

# 3. Remaining PyPI deps
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install \
    av>=16.1.0 \
    numpy \
    psutil \
    diffusers \
    accelerate \
    huggingface-hub \
    mmengine==0.10.7 \
    opencv-python \
    Pillow \
    tqdm \
    customtkinter \
    tkinterdnd2 \
    ultralytics \
    onnx \
    "cryptography>=42" \
    pynvvideocodec \
    nvidia-vfx

# 4. Kruk2's git forks (PyPI versions have incompatible APIs)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --no-build-isolation \
    "python-vali @ git+https://codeberg.org/Kruk2/vali.git" \
    "pynvvideocodec @ git+https://codeberg.org/Kruk2/PyNvVideoCodec.git"

# ---------------------------------------------------------------------------
# Patches
# ---------------------------------------------------------------------------
COPY patches/ patches/
RUN SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])") \
    && patch -d "$SITE_PACKAGES" -p1 \
    < /app/patches/fix_loading_mmengine_weights_on_torch26_and_higher.diff

# ---------------------------------------------------------------------------
# FFmpeg 8.1 static build
# ---------------------------------------------------------------------------
RUN curl -fsSL \
    "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.1-latest-linux64-gpl-8.1.tar.xz" \
    -o /tmp/ffmpeg.tar.xz \
    && tar -xf /tmp/ffmpeg.tar.xz -C /usr/local --strip-components=1 --no-same-owner \
    && rm -rf /tmp/ffmpeg.tar.xz

# ---------------------------------------------------------------------------
# Project source + installation
# ---------------------------------------------------------------------------
COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --no-build-isolation -e .

# ---------------------------------------------------------------------------
# Runtime configuration
# ---------------------------------------------------------------------------
ENV DISPLAY=:0
ENV QT_X11_NO_MITSHM=1
ENV NVIDIA_DRIVER_CAPABILITIES=compute,video,utility,graphics

ENTRYPOINT ["python", "-m", "jasna"]
CMD []
