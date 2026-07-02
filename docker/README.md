# Jasna Docker

## 前置条件

- Docker Engine 24+
- [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- NVIDIA 显卡驱动 ≥ 580（RTX 3060 可用）
- 已下载的模型权重文件（见 `model_weights/`）

## 文件结构

```
.
├── Dockerfile           # 多阶段构建 (CUDA 13.0 + uv + Python 3.13)
├── docker-compose.yml   # 容器编排 (GPU + X11 + 卷挂载)
├── docker/
│   └── README.md        # 本文件
├── model_weights/       # 模型权重 (挂载为 volume, 持久化 TRT engine)
│   ├── lada_mosaic_restoration_model_generic_v1.2.pth
│   └── rfdetr-v5.onnx
├── input/               # 输入文件目录 (挂载到容器 /input)
└── output/              # 输出文件目录 (挂载到容器 /output)
```

## 快速开始

```bash
# 构建镜像 (首次需 30-60 分钟，含下载 CUDA 基镜像 + PyTorch + TensorRT)
docker compose build

# 查看帮助
docker compose run --rm jasna

# CLI 处理单个视频（输出文件属主为当前用户）
MY_UID=$(id -u) MY_GID=$(id -g) docker compose run --rm jasna \
  --input /input/video.mp4 \
  --output /output/restored.mkv

# GUI 模式
xhost +local:
docker compose up
```

## CLI 参考

### 基本用法

```bash
docker compose run --rm jasna --input /input/video.mp4 --output /output/out.mkv
```

### 全部参数

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--input PATH` | 输入文件/文件夹路径 | — |
| `--output PATH` | 输出文件/文件夹路径 | — |
| `--output-pattern TEMPLATE` | 批量输出文件名模板，如 `{original}_restored.mp4` | `{original}_out` |
| `--batch-size N` | 批处理大小 | 4 |
| `--device DEVICE` | 计算设备 | `cuda:0` |
| `--fp16` / `--no-fp16` | 启用 FP16（减少 VRAM） | 开启 |
| `--log-level LEVEL` | 日志级别: debug/info/warning/error | error |
| `--disable-ffmpeg-check` | 跳过 ffmpeg 版本检查 | — |
| `--no-progress` | 隐藏进度条 | — |

**恢复模型 (Restoration)**

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--restoration-model-name NAME` | 恢复模型名称（仅 basicvsrpp） | basicvsrpp |
| `--restoration-model-path PATH` | 恢复模型权重路径 | `model_weights/lada_mosaic_restoration_model_generic_v1.2.pth` |
| `--compile-basicvsrpp` / `--no-compile-basicvsrpp` | 编译 TensorRT engine（提升速度，增加 VRAM） | 开启 |
| `--max-clip-size N` | 最大 clip 帧数（RTX 3060 推荐 60-90） | 90 |
| `--temporal-overlap N` | 时间重叠帧数 | 8 |
| `--enable-crossfade` / `--no-enable-crossfade` | clip 边界交叉淡化 | 开启 |
| `--denoise LEVEL` | 空间降噪: none/low/medium/high | none |
| `--denoise-step STEP` | 降噪时机: after_primary / after_secondary | after_primary |

**二次恢复 (2nd restoration)**

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--secondary-restoration TYPE` | 二次恢复: none/unet-4x/tvai/rtx-super-res | none |
| `--rtx-scale {2,4}` | RTX Super Res 放大倍数 | 4 |
| `--rtx-quality LEVEL` | RTX Super Res 质量: low/medium/high/ultra | high |
| `--rtx-denoise LEVEL` | RTX Super Res 降噪: none/low/medium/high/ultra | medium |
| `--rtx-deblur LEVEL` | RTX Super Res 去模糊: none/low/medium/high/ultra | none |

**检测模型 (Detection)**

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--detection-model NAME` | 检测模型名 | rfdetr-v5 |
| `--detection-model-path PATH` | 检测模型路径（覆盖 --detection-model） | — |
| `--detection-score-threshold N` | 检测分数阈值 | 0.25 |

**编码 (Encoding)**

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--codec CODEC` | 视频编码器（仅 hevc） | hevc |
| `--encoder-settings KV` | 编码器参数，如 `cq=22,lookahead=32` | — |
| `--working-directory DIR` | 编码临时文件目录 | 同输出目录 |
| `--lut PATH` | .cube 色彩 LUT 文件 | — |

**SD 1.5 图片恢复**

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--image-restoration-model-name NAME` | 图片恢复模型（仅 sd-15-jav） | sd-15-jav |
| `--sd15-steps N` | 扩散步数 | 25 |
| `--sd15-strength N` | 去噪强度（上限 0.7） | 0.6 |
| `--sd15-freeu` / `--no-sd15-freeu` | 启用 FreeU | 开启 |
| `--sd15-seed N` | 随机种子 | 0 |
| `--sd15-variants N` | 生成变体数量 | 1 |

**流媒体 (Streaming)**

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--stream` | 启用 HLS 流模式 | — |
| `--stream-port PORT` | HTTP 端口 | 8765 |
| `--stream-segment-duration N` | HLS 分片时长（秒） | 4.0 |
| `--no-browser` | 不自动打开浏览器 | — |

**后处理动作**

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--post-export-action ACTION` | 完成后动作: none/shutdown/command | none |
| `--post-export-command CMD` | 自定义 shell 命令 | — |

### 使用示例

```bash
# 使用自定义检测模型 + 关闭 FP16
docker compose run --rm jasna \
  --input /input/video.mp4 \
  --output /output/out.mkv \
  --detection-model rfdetr-v5 \
  --no-fp16

# 文件夹批量处理
docker compose run --rm jasna \
  --input /input \
  --output /output \
  --output-pattern "{original}_restored.mp4"

# 调低 clip size 适配 12GB VRAM
docker compose run --rm jasna \
  --input /input/video.mp4 \
  --output /output/out.mkv \
  --max-clip-size 90 \
  --temporal-overlap 8 \
  --enable-crossfade

# 不使用 TensorRT 编译 restoration model (减少 VRAM)
docker compose run --rm jasna \
  --input /input/video.mp4 \
  --output /output/out.mkv \
  --no-compile-basicvsrpp
```

## GUI 模式

宿主机需要安装 `xorg-xhost`（Arch Linux）或 `x11-xserver-utils`（Debian/Ubuntu）：

```bash
# Arch Linux
sudo pacman -S xorg-xhost

# Debian/Ubuntu
sudo apt install x11-xserver-utils
```

首次运行 GUI 前需要允许 X11 连接：

```bash
xhost +local:
docker compose up
```

然后在 GUI 中添加视频、调整设置、开始处理。

完成后关闭 GUI (`Ctrl+C`)，恢复 X11 访问控制：

```bash
xhost -local:
```

## 模型权重

`model_weights/` 目录已挂载为 Docker volume，编译后的 TensorRT engine 会缓存于此。
容器重建后不会丢失已编译的 engine。

如需额外模型，从 GitHub Releases 下载后放入 `model_weights/`：

| 模型 | 文件 | 来源 |
|---|---|---|
| 主恢复模型 | `lada_mosaic_restoration_model_generic_v1.2.pth` | Lada v0.6.0 |
| RF-DETR v5 | `rfdetr-v5.onnx` | Jasna v0.7.1 |
| RF-DETR v2/v3/v4 | `rfdetr-v{2,3,4}.onnx` | Jasna 旧版 release |
| Lada YOLO v2/v4 | `lada_mosaic_detection_model_v{2,4_fast}.pt` | Lada release |

## 故障排除

### GPU 不可用

确认 nvidia-container-toolkit 已安装且 Docker 已配置：

```bash
docker run --rm --gpus all nvidia/cuda:13.0.0-runtime-ubuntu24.04 nvidia-smi
```

如果 `runtime: nvidia` 不工作，在 `docker-compose.yml` 中注释掉 `runtime:` 行，取消注释 `deploy:` 块。

### X11 权限错误

```bash
xhost +local:
```

如果仍有问题，尝试：

```bash
# 方式 1: 以宿主机用户身份运行
docker compose run --rm -u $(id -u):$(id -g) jasna --help

# 方式 2: 使用 host 网络模式
docker compose run --rm --network host jasna --help
```

### /tmp/.X11-unix 不存在

检查 DISPLAY 环境变量是否正确：

```bash
echo $DISPLAY  # 通常为 :0 或 :1
```

### 编译 TRT engine 时 OOM

RTX 3060 12GB 建议降低 clip size：

```bash
--max-clip-size 60 --temporal-overlap 6
```

或完全禁用 BasicVSR++ 编译：

```bash
--no-compile-basicvsrpp
```

## 编码质量

输出使用 NVENC HEVC 硬件编码，核心参数 `cq`（Constant Quality），**值越低质量越高、文件越大**。

| cq 值 | 画质 | 文件大小 | 适用场景 |
|-------|------|---------|---------|
| 18-20 | 接近无损 | 很大 | 存档/收藏 |
| 22-25 | 优秀 | 适中 | 默认(25) |
| 28-30 | 可接受 | 较小 | 预览/临时 |
| 35+ | 差 | 很小 | 不推荐 |

**preset**（编码器预设，P1最快↔P7最慢）：

| preset | 速度 | 同码率画质 |
|--------|------|-----------|
| P1-P3 | 极快 | 差 |
| P4 | 快 | 一般 |
| P5 | 中等 | 好（默认） |
| P6 | 较慢 | 优秀（推荐） |
| P7 | 最慢 | 最佳 |

**示例**：

```bash
# 高质量（cq 降低 + 慢预设）
MY_UID=$(id -u) MY_GID=$(id -g) docker compose run --rm jasna \
  --input /input/video.mp4 \
  --output /output/out.mkv \
  --encoder-settings cq=20,preset=P6

# 平衡推荐
--encoder-settings cq=22,preset=P6

# 限制码率
--encoder-settings cq=22,preset=P6,maxbitrate=30000
```

`maxbitrate` 单位 kbps。1080p 建议 `maxbitrate=20000`（~20 Mbps）。

## 画质调优

### 恢复区域有明显边界

这是 256x256 crop 恢复后 blend 回原帧时的固有效果。二次恢复（RTX Super Res）放大到 1024x1024 后与原帧差异变大，边界更明显。

缓解方法：

1. **关掉二次恢复**（边界最不明显，但画质较糊）：
   ```bash
   --secondary-restoration none
   ```

2. **降低二次放大倍数**（平衡画质与边界）：
   ```bash
   --rtx-scale 2
   ```

3. **启用降噪**（软化边缘）：
   ```bash
   --denoise high
   ```

推荐组合：

```bash
MY_UID=$(id -u) MY_GID=$(id -g) docker compose run --rm jasna \
  --input /input/video.mp4 \
  --output /output/out.mkv \
  --max-clip-size 180 \
  --temporal-overlap 15 \
  --secondary-restoration rtx-super-res \
  --rtx-scale 2 \
  --rtx-quality ultra \
  --rtx-denoise medium
```

### 权限问题

`input/` 和 `output/` 目录需要容器有写权限。使用前创建：

```bash
mkdir -p input output
```


### 改善效果的主要参数：
时间一致性（减少闪烁）：
- --max-clip-size 180 — 更大的 clip 大小，时间连续性更好（VRAM 需求更高）
- --temporal-overlap 15 — 增加重叠帧数，clip 边界更平滑
- --enable-crossfade（默认开启）— clip 间交叉淡化
画质：
- --secondary-restoration rtx-super-res — 二次放大，大幅提升细节清晰度
- --denoise medium — 降噪，减少伪影
- --no-fp16 — 使用 FP32 精度（VRAM 更高，但轻微改善画质）
RTX 3060 12GB 推荐组合（效果优先）：
docker compose run --rm jasna \
  --input /input/video.mp4 \
  --output /output/out.mkv \
  --max-clip-size 180 \
  --temporal-overlap 15 \
  --secondary-restoration rtx-super-res \
  --rtx-quality ultra \
  --rtx-denoise medium
如果 VRAM 不足（OOM），先降 --max-clip-size 到 90 或关闭 --rtx-denoise。