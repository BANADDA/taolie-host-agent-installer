# GPU Detection and Mode Selection

This document explains how the Taolie Host Agent installer automatically detects your hardware and selects the appropriate deployment mode (GPU or CPU).

## Overview

The installer features **intelligent hardware detection** that:

- ✅ Automatically detects NVIDIA GPUs
- ✅ Validates GPU accessibility
- ✅ Tests NVIDIA Container Toolkit
- ✅ Falls back to CPU mode when needed
- ✅ Allows manual override with `--cpu-only` flag

## Detection Flow

### Step-by-Step Process

```
┌─────────────────────────────────────────────┐
│  Start Installation                         │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │ --cpu-only flag set?│
         └─────────┬───────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
        YES                 NO
         │                   │
         ▼                   ▼
    ┌────────┐      ┌──────────────────┐
    │CPU Mode│      │Check nvidia-smi  │
    └────────┘      └────────┬─────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                  Found           Not Found
                    │                 │
                    ▼                 ▼
         ┌──────────────────┐    ┌────────┐
         │ Run nvidia-smi   │    │CPU Mode│
         │ Get GPU info     │    └────────┘
         └────────┬─────────┘
                  │
         ┌────────┴────────┐
         │                 │
      Success           Failure
         │                 │
         ▼                 ▼
┌─────────────────┐   ┌────────┐
│Check NVIDIA     │   │CPU Mode│
│Container Toolkit│   └────────┘
└────────┬────────┘
         │
┌────────┴────────┐
│                 │
Configured    Not Configured
│                 │
▼                 ▼
┌────────┐   ┌────────────┐
│GPU Mode│   │Exit with   │
└────────┘   │Error       │
             └────────────┘
```

## Detection Stages

### Stage 1: Manual Override Check

**What it does:** Checks if user specified `--cpu-only` flag

**Code:**
```bash
if [ "$CPU_ONLY" = true ]; then
    print_info "Running in CPU-only mode (--cpu-only flag set)"
fi
```

**Result:**
- If `--cpu-only` is set → Skip all GPU detection, use CPU mode
- If not set → Continue to next stage

**Use case:** User wants to force CPU mode even if GPU is available

---

### Stage 2: nvidia-smi Command Check

**What it does:** Checks if `nvidia-smi` command exists

**Code:**
```bash
if command -v nvidia-smi &> /dev/null; then
    # nvidia-smi exists, continue
else
    print_warning "nvidia-smi not found. Switching to CPU-only mode."
    CPU_ONLY=true
fi
```

**Result:**
- If `nvidia-smi` not found → CPU mode
- If `nvidia-smi` found → Continue to next stage

**Common reasons for failure:**
- NVIDIA drivers not installed
- Wrong driver version
- Driver installation incomplete

---

### Stage 3: GPU Information Retrieval

**What it does:** Attempts to get GPU information using `nvidia-smi`

**Code:**
```bash
GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
if [ -n "$GPU_INFO" ]; then
    print_success "NVIDIA GPU detected: $GPU_INFO"
else
    print_warning "No NVIDIA GPU detected. Switching to CPU-only mode."
    CPU_ONLY=true
fi
```

**Result:**
- If GPU info retrieved → Continue to next stage
- If no GPU info → CPU mode

**What it detects:**
- GPU model name (e.g., "NVIDIA GeForce RTX 3090")
- Number of GPUs (uses first one)

**Common reasons for failure:**
- GPU not properly seated
- Driver issues
- GPU disabled in BIOS

---

### Stage 4: NVIDIA Container Toolkit Validation

**What it does:** Tests if Docker can access the GPU

**Code:**
```bash
if docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi &> /dev/null; then
    print_success "NVIDIA Container Toolkit is properly configured"
else
    print_error "NVIDIA Container Toolkit is not properly configured!"
    exit 1
fi
```

**Result:**
- If test succeeds → GPU mode
- If test fails → **Exit with error** (does not fall back to CPU)

**Why exit instead of fallback?**
- GPU was detected but Docker can't access it
- This indicates a configuration problem that should be fixed
- User likely expects GPU mode if they have a GPU

**Common reasons for failure:**
- NVIDIA Container Toolkit not installed
- Docker daemon not restarted after toolkit installation
- Incorrect toolkit configuration

---

## Deployment Modes

### GPU Mode

**Activated when:**
- All detection stages pass successfully
- GPU detected and accessible via Docker

**Docker Command:**
```bash
docker run -d \
  --name taolie-host-agent \
  --restart unless-stopped \
  --runtime nvidia \                    # GPU runtime
  --privileged \
  --network taolie-network \
  -e NVIDIA_VISIBLE_DEVICES=all \       # Make all GPUs visible
  -e NVIDIA_DRIVER_CAPABILITIES=all \   # Enable all GPU capabilities
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/config.yaml:/etc/taolie-host-agent/config.yaml:ro \
  -v taolie_agent_logs:/var/log/taolie-host-agent \
  ghcr.io/banadda/host-agent:latest
```

**Key Differences:**
- `--runtime nvidia`: Uses NVIDIA container runtime
- `NVIDIA_VISIBLE_DEVICES=all`: Exposes all GPUs to container
- `NVIDIA_DRIVER_CAPABILITIES=all`: Enables compute, utility, graphics capabilities

**Capabilities Enabled:**
- `compute`: CUDA and OpenCL
- `utility`: nvidia-smi and NVML
- `graphics`: OpenGL and Vulkan
- `video`: Video encoding/decoding
- `display`: X11 display

---

### CPU Mode

**Activated when:**
- `--cpu-only` flag is set, OR
- `nvidia-smi` not found, OR
- No GPU information retrieved, OR
- User chooses CPU mode during installation

**Docker Command:**
```bash
docker run -d \
  --name taolie-host-agent \
  --restart unless-stopped \
  --privileged \
  --network taolie-network \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/config.yaml:/etc/taolie-host-agent/config.yaml:ro \
  -v taolie_agent_logs:/var/log/taolie-host-agent \
  ghcr.io/banadda/host-agent:latest
```

**Key Differences:**
- No `--runtime nvidia`
- No GPU environment variables
- Same image, different runtime configuration

**Use Cases:**
- Servers without GPU
- CPU-only compute tasks
- Testing or development
- Cost-effective compute provision

---

## Manual Override

### Force CPU Mode

Even if you have a GPU, you can force CPU mode:

```bash
curl -fsSL [...]/install.sh | bash -s -- \
  --api-key YOUR_KEY \
  --cpu-only
```

**When to use:**
- GPU reserved for other tasks
- Testing CPU performance
- Troubleshooting GPU issues
- Running multiple instances (one GPU, one CPU)

---

## Verification

### After Installation

**Check which mode was used:**

```bash
# View installation summary
# Look for "Mode: GPU-enabled" or "Mode: CPU-only"

# Or inspect container
docker inspect taolie-host-agent | grep -i nvidia
```

**If GPU mode:**
```json
"Runtime": "nvidia",
"Env": [
    "NVIDIA_VISIBLE_DEVICES=all",
    "NVIDIA_DRIVER_CAPABILITIES=all"
]
```

**If CPU mode:**
```json
"Runtime": "runc",  // or empty
"Env": [
    // No NVIDIA variables
]
```

### Verify GPU Access in Container

**For GPU mode:**
```bash
docker exec taolie-host-agent nvidia-smi
```

Expected output: GPU information (same as host `nvidia-smi`)

**For CPU mode:**
```bash
docker exec taolie-host-agent nvidia-smi
```

Expected output: Command not found (this is normal)

---

## Troubleshooting Detection

### GPU Not Detected But Should Be

**Check host GPU:**
```bash
nvidia-smi
```

If this works, but installer doesn't detect GPU:

**Check NVIDIA Container Toolkit:**
```bash
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi
```

If this fails:
```bash
# Reinstall NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

---

### Installer Exits at Stage 4

**Error message:**
```
✗ NVIDIA Container Toolkit is not properly configured!
```

**This means:**
- GPU was detected (Stage 3 passed)
- But Docker can't access it (Stage 4 failed)

**Solution:**

Install NVIDIA Container Toolkit (see above), then run installer again.

---

### Want CPU Mode But GPU Detected

**Use the flag:**
```bash
curl -fsSL [...]/install.sh | bash -s -- \
  --api-key YOUR_KEY \
  --cpu-only
```

---

## Detection Logic in Code

### Key Variables

```bash
# Default value
CPU_ONLY=false

# Set to true in these cases:
# 1. User passes --cpu-only flag
# 2. nvidia-smi not found
# 3. nvidia-smi returns no GPU info
# 4. User chooses CPU mode during installation
```

### Decision Point

```bash
if [ "$CPU_ONLY" = true ]; then
    # Deploy CPU mode
    print_info "Deploying in CPU-only mode..."
    docker run -d ... # CPU command
else
    # Deploy GPU mode
    print_info "Deploying with GPU support..."
    docker run -d --runtime nvidia ... # GPU command
fi
```

---

## Best Practices

### For GPU Users

1. **Install NVIDIA drivers first**
   ```bash
   sudo ubuntu-drivers autoinstall
   sudo reboot
   ```

2. **Install NVIDIA Container Toolkit**
   ```bash
   # See prerequisites.md for full instructions
   ```

3. **Verify before installing**
   ```bash
   nvidia-smi
   docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi
   ```

4. **Then run installer**
   ```bash
   curl -fsSL [...]/install.sh | bash -s -- --api-key YOUR_KEY
   ```

### For CPU Users

1. **Just run installer**
   ```bash
   curl -fsSL [...]/install.sh | bash -s -- --api-key YOUR_KEY
   ```

2. **Or explicitly specify CPU mode**
   ```bash
   curl -fsSL [...]/install.sh | bash -s -- \
     --api-key YOUR_KEY \
     --cpu-only
   ```

---

## Comparison: GPU vs CPU Mode

| Feature | GPU Mode | CPU Mode |
|---------|----------|----------|
| **Hardware Required** | NVIDIA GPU | Any CPU |
| **Driver Required** | NVIDIA drivers | None |
| **Toolkit Required** | NVIDIA Container Toolkit | None |
| **Docker Runtime** | `nvidia` | `runc` (default) |
| **Environment Variables** | `NVIDIA_VISIBLE_DEVICES`<br>`NVIDIA_DRIVER_CAPABILITIES` | None |
| **Container Access** | Full GPU access | CPU only |
| **Use Cases** | AI/ML training<br>GPU mining<br>Rendering<br>Video encoding | Web services<br>CPU mining<br>General compute<br>Development |
| **Performance** | High for GPU tasks | High for CPU tasks |
| **Power Consumption** | Higher | Lower |
| **Cost** | Higher (GPU hardware) | Lower |
| **Earnings Potential** | Higher (GPU rentals) | Lower (CPU rentals) |

---

## Summary

The Taolie Host Agent installer features **smart GPU detection** that:

✅ **Automatically detects** your hardware configuration
✅ **Validates** GPU accessibility through Docker
✅ **Falls back gracefully** to CPU mode when needed
✅ **Allows manual override** for advanced users
✅ **Provides clear feedback** about which mode is being used

**You don't need to worry about choosing the right mode** - the installer does it for you!

But if you want control, you can always use the `--cpu-only` flag.
