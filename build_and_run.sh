#!/bin/bash

# ComfyUI RunPod Build & Run Script
set -e

echo "🚀 ComfyUI RunPod Build & Deploy Script"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check requirements
check_requirements() {
    log_info "Checking requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        exit 1
    fi
    log_success "Docker found: $(docker --version)"
    
    # Check NVIDIA Docker (optional)
    if ! docker run --rm --gpus all nvidia/cuda:12.1.1-base-ubuntu22.04 nvidia-smi &>/dev/null; then
        log_warning "NVIDIA Docker runtime not available - will run CPU-only"
        GPU_SUPPORT=false
    else
        log_success "NVIDIA Docker runtime available"
        GPU_SUPPORT=true
    fi
}

# Build image
build_image() {
    log_info "Building ComfyUI image..."
    
    # Enable BuildKit for faster builds
    export DOCKER_BUILDKIT=1
    export BUILDKIT_PROGRESS=plain
    
    # Build with progress
    docker build \
        --progress=plain \
        --tag comfyui-runpod-s3:latest \
        --build-arg MAX_JOBS=4 \
        --build-arg CMAKE_BUILD_PARALLEL_LEVEL=4 \
        . 2>&1 | tee build.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Build completed successfully!"
    else
        log_error "Build failed! Check build.log for details."
        exit 1
    fi
}

# Create directories
setup_directories() {
    log_info "Setting up directories..."
    
    mkdir -p models/{checkpoints,vae,loras,embeddings,hypernetworks,unet}
    mkdir -p input
    mkdir -p output
    
    log_success "Directories created"
}

# Run container
run_container() {
    log_info "Starting ComfyUI container..."
    
    # Stop existing container if running
    docker stop comfyui-production 2>/dev/null || true
    docker rm comfyui-production 2>/dev/null || true
    
    # GPU or CPU run command
    if [ "$GPU_SUPPORT" = true ]; then
        DOCKER_RUN_CMD="docker run -d \
            --name comfyui-production \
            --gpus all \
            -p 8188:8188 \
            -v $(pwd)/models:/workspace/ComfyUI/models \
            -v $(pwd)/input:/workspace/ComfyUI/input \
            -v $(pwd)/output:/workspace/ComfyUI/output \
            --restart unless-stopped \
            comfyui-runpod-s3:latest"
    else
        DOCKER_RUN_CMD="docker run -d \
            --name comfyui-production \
            -p 8188:8188 \
            -v $(pwd)/models:/workspace/ComfyUI/models \
            -v $(pwd)/input:/workspace/ComfyUI/input \
            -v $(pwd)/output:/workspace/ComfyUI/output \
            --restart unless-stopped \
            comfyui-runpod-s3:latest"
    fi
    
    # Execute run command
    eval $DOCKER_RUN_CMD
    
    log_success "Container started!"
    log_info "ComfyUI will be available at: http://localhost:8188"
    log_info "Container name: comfyui-production"
}

# Monitor container
monitor_container() {
    log_info "Monitoring container startup..."
    
    # Wait for container to be ready
    for i in {1..60}; do
        if curl -s http://localhost:8188/ >/dev/null 2>&1; then
            log_success "ComfyUI is ready!"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Show logs
    echo -e "\n${BLUE}=== Container Logs ===${NC}"
    docker logs comfyui-production --tail 20
}

# Main execution
main() {
    echo "Starting ComfyUI RunPod deployment..."
    echo "Build time estimate: 15-25 minutes"
    echo ""
    
    # Parse command line arguments
    SKIP_BUILD=false
    SKIP_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-run)
                SKIP_RUN=true
                shift
                ;;
            --build-only)
                SKIP_RUN=true
                shift
                ;;
            --run-only)
                SKIP_BUILD=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --skip-build    Skip building the image"
                echo "  --skip-run      Skip running the container"
                echo "  --build-only    Only build the image"
                echo "  --run-only      Only run the container"
                echo "  -h, --help      Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execute steps
    check_requirements
    setup_directories
    
    if [ "$SKIP_BUILD" = false ]; then
        build_image
    fi
    
    if [ "$SKIP_RUN" = false ]; then
        run_container
        sleep 5
        monitor_container
    fi
    
    echo ""
    log_success "ComfyUI RunPod deployment complete!"
    echo ""
    echo "📊 Access ComfyUI:"
    echo "   Local: http://localhost:8188"
    echo "   RunPod: http://your-runpod-url:8188"
    echo ""
    echo "🔧 Useful commands:"
    echo "   View logs: docker logs -f comfyui-production"
    echo "   Stop: docker stop comfyui-production"
    echo "   Restart: docker restart comfyui-production"
    echo "   Shell access: docker exec -it comfyui-production bash"
}

# Execute main function
main "$@"