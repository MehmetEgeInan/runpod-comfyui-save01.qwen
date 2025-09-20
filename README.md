/input
/models/checkpoint - qwen model place
       /embeddings
       /hypernetworks
       /loras
       /unet
       /vae
/output





# ComfyUI RunPod S3 Integration

🚀 **Production-ready ComfyUI with AWS S3 integration for RunPod deployment**

## 🌟 Features

- ✅ **ComfyUI** with latest updates
- ✅ **Qwen Image Model** (40GB) support  
- ✅ **AWS S3 Integration** for automatic upload
- ✅ **Custom Nodes** pre-installed
- ✅ **GPU Optimized** (CUDA 12.1 + PyTorch 2.4.1)
- ✅ **RunPod Ready** for instant deployment
- ✅ **Serverless Support** for API usage

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ComfyUI UI   │────│  Docker Container │────│   AWS S3 Bucket │
│  (Port 8188)   │    │    GPU Enabled    │    │  Auto Upload    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                       ┌──────────────────┐
                       │  RunPod Platform │
                       │   GPU Instances  │
                       └──────────────────┘
```

## 📦 Included Components

### Core Systems
- **ComfyUI**: Latest stable version
- **PyTorch**: 2.4.1+cu121 with CUDA 12.1
- **xformers**: 0.0.28.post1 for optimization
- **flash-attention**: 2.5.0+ for speed

### Custom Nodes
- ComfyUI-Manager
- ComfyUI-VideoHelperSuite
- ComfyUI-KJNodes
- ComfyUI-WanVideoWrapper
- controlnet-aux nodes
- WAS Node Suite

### Models Support
- **Text-to-Image (T2I)** generation
- **Image-to-Image (I2I)** processing
- **Video processing** capabilities
- **ControlNet** integration

## 🚀 RunPod Deployment

### Quick Deploy

1. **Fork this repository** to your GitHub
2. **Create RunPod Template**:
   - Use `runpod-template.json` configuration
   - Set Git repository URL
   - Configure environment variables
3. **Deploy Pod** with minimum RTX 4090 GPU
4. **Wait 15-25 minutes** for build completion
5. **Access via** pod URL:8188

### Detailed Instructions

📖 **[Complete Deployment Guide](RUNPOD_DEPLOYMENT.md)**

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RUN_MODE` | `ui` | `ui` for web interface, `serverless` for API |
| `QWEN_REPO_ID` | `Qwen/Qwen-Image` | HuggingFace model repository |
| `QWEN_FILENAME` | `qwen_image_distill_full_bf16.safetensors` | Model filename |
| `HF_TOKEN` | - | HuggingFace token (optional) |

### Volume Mounts

```
/workspace/ComfyUI/models  → /models  (persistent)
/workspace/ComfyUI/input   → /input   (temporary)
/workspace/ComfyUI/output  → /output  (S3 sync)
```

## 🔌 S3 Integration

### Auto Upload Features
- ✅ Automatic output file upload to S3
- ✅ Configurable folder structure
- ✅ Metadata tracking
- ✅ Error handling with fallback
- ✅ File size and type validation

### Configuration
Edit `s3UploaderForLocals/s3_config.py`:
```python
ACCESS_KEY = "your_access_key"
SECRET_KEY = "your_secret_key" 
BUCKET_NAME = "your_bucket_name"
REGION = "your_region"
```

## 📊 Hardware Requirements

### Minimum
- **GPU**: RTX 4090 (24GB VRAM)
- **RAM**: 16GB
- **Storage**: 50GB container + 100GB volume
- **CPU**: 4+ cores

### Recommended
- **GPU**: A100 (40GB/80GB VRAM)
- **RAM**: 32GB
- **Storage**: 100GB container + 200GB volume
- **CPU**: 8+ cores

## 🔗 API Usage

### Serverless Mode

Set `RUN_MODE=serverless` and use webhook endpoint:

```bash
curl -X POST https://your-pod-id.proxy.runpod.net/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "workflow": {...},
      "mode": "t2i",
      "images": [...]
    }
  }'
```

### Response Format
```json
{
  "result": {
    "status": "success",
    "s3_url": "https://bucket.s3.region.amazonaws.com/output.png",
    "file_size": 1024000
  }
}
```

## 🛠️ Local Development

### Build & Run
```bash
# Build image
docker build -t comfyui-runpod-s3:latest .

# Run with GPU
docker run --gpus all -p 8188:8188 \
  -v ./models:/workspace/ComfyUI/models \
  -v ./output:/workspace/ComfyUI/output \
  comfyui-runpod-s3:latest

# Or use the build script
chmod +x build_and_run.sh
./build_and_run.sh
```

### Access
- **Web UI**: http://localhost:8188
- **Models**: Place in `./models/checkpoints/`
- **Outputs**: Generated in `./output/` and uploaded to S3

## 📈 Performance Tips

1. **Use SSD storage** for volume mounts
2. **Enable BuildKit** for faster builds: `export DOCKER_BUILDKIT=1`
3. **Use spot instances** on RunPod for cost savings
4. **Monitor GPU memory** usage in real-time
5. **Auto-pause pods** when not in use

## 🔧 Troubleshooting

### Build Issues
```bash
# Check logs
docker logs container_name

# Debug build
docker build --progress=plain --no-cache .
```

### Runtime Issues
```bash
# Test S3 connection
docker exec container_name python3 -c "
from s3UploaderForLocals import S3Uploader
print(S3Uploader().test_connection())
"

# Check GPU
docker exec container_name nvidia-smi
```

## 📝 File Structure

```
comfyui-runpod-s3/
├── Dockerfile                 # Main container definition
├── docker-compose.yml         # Local development setup
├── build_and_run.sh          # Build automation script
├── runpod-template.json       # RunPod template config
├── RUNPOD_DEPLOYMENT.md       # Deployment guide
├── serverless/
│   ├── handler.py             # RunPod serverless handler
│   └── entrypoint.sh          # Container entrypoint
├── s3UploaderForLocals/
│   ├── __init__.py
│   ├── s3_config.py           # S3 configuration
│   └── s3_uploader.py         # S3 upload logic
├── models/                    # Model storage (volume mount)
├── input/                     # Input files
└── output/                    # Generated outputs
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **RunPod Docs**: [docs.runpod.io](https://docs.runpod.io)

---

**🎨 Ready to generate amazing AI art with ComfyUI on RunPod! 🚀**
