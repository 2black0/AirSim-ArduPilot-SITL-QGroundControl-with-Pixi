# AirSim-ArduPilot SITL Simulation Environment

![AirSim-ArduPilotSITL](additional-readme/image.png)

This project provides a streamlined setup for running AirSim environment with ArduPilot SITL (Software In The Loop) and QGroundControl, managed entirely through Pixi for reproducible builds.

## Overview

The simulation environment consists of three main components:
- **AirSim** (AirSimNH environment) - Unreal Engine-based simulator
- **ArduPilot SITL** - Software-in-the-loop flight controller
- **QGroundControl** - Ground control station

All dependencies are managed through Pixi, ensuring a consistent and isolated build environment without requiring system-wide package installations.

## Prerequisites

- **Pixi** package manager ([installation guide](https://pixi.sh))
- **Linux** (tested on Ubuntu 22.04 LTS)
- **x86_64 architecture**

## Quick Start

### 1. Install Dependencies

Initialize the Pixi environment with all required build tools and Python packages:

```bash
pixi install
```

This will create an isolated `simulation` environment with:
- Build toolchain (gcc, g++, make, pkg-config, ccache)
- Development tools (git, wget, unzip, rsync)
- Python packages (empy, pexpect, dronecan, pymavlink, MAVProxy, etc.)

### 2. Activate Pixi Environment

Enter the simulation environment:

```bash
pixi shell -e simulation
```

All subsequent commands should be run within this shell.

### 3. Download Components

Download AirSim environment:

```bash
./scripts/download-airsim.sh
```

This will:
- Download AirSimNH environment (v1.8.1) from Microsoft AirSim releases
- Extract to `.airsim_ardupilot/airsim/AirSimNH/`
- Copy configuration from `scripts/config/airsim/settings.json`
- Create symlink at `~/Documents/AirSim/settings.json`

Download QGroundControl:

```bash
./scripts/download-qground.sh
```

This will:
- Download latest QGroundControl AppImage
- Save to `.airsim_ardupilot/qgroundcontrol/`
- Make executable automatically

### 4. Build ArduPilot SITL

Compile ArduCopter for SITL:

```bash
./scripts/build-ardupilot-sitl.sh
```

This will:
- Clone ArduPilot repository (if not present)
- Update all submodules
- Configure and build ArduCopter binary for SITL
- Output binary at `.airsim_ardupilot/ardupilot/build/sitl/bin/arducopter`

Build options:
- `--clean` - Remove previous build artifacts
- `--force-clone` - Delete and re-clone ArduPilot repository

### 5. Verify Installation

Check that all components are ready:

```bash
./scripts/check-simulation.sh
```

This validates:
- AirSim environment and launcher
- QGroundControl AppImage
- ArduPilot SITL binary
- Pixi environment status

## Configuration

### AirSim Settings

Configuration file: `scripts/config/airsim/settings.json`

Key settings:
- **Vehicle Type**: ArduCopter
- **Origin**: Lat -7.2823507, Lon 112.7923504, Alt 20m
- **Ports**: UDP 9003, Control 9002
- **Camera**: 1280x720, 90° FOV, pitch -90°
- **Sensors**: Barometer, IMU, GPS, Magnetometer enabled
- **ViewMode**: FlyWithMe (default)

### ArduPilot Parameters

Configuration file: `scripts/config/ardupilot/airsim.parm`

Optimized parameters for AirSim SITL:
- `SCHED_LOOP_RATE=180` - Reduced scheduler rate for stability
- `WPNAV_SPEED=140` - Limited waypoint speed (5 km/h)
- `ANGLE_MAX=1500` - Restricted attitude authority
- `WPNAV_ACCEL=50` - Smooth waypoint acceleration
- `SIM_SPEEDUP=20` - Simulation speedup factor
- GPS and failsafe thresholds relaxed for testing

## Running the Simulation

### Simple Run (Recommended)

Start all components together:

```bash
./scripts/run-simulation.sh
```

Options:
- `--no-display` - Run AirSim in headless mode (NoDisplay)
- `--help` - Show usage information

This will:
1. Update ViewMode in settings.json based on display flag
2. Start QGroundControl (background)
3. Start AirSim environment (background)
4. Start ArduPilot SITL with parameter file (foreground)

Press `Ctrl+C` to stop all components gracefully.

### Manual Component Startup

If you prefer to start components individually:

```bash
# Terminal 1: QGroundControl
.airsim_ardupilot/qgroundcontrol/QGroundControl-x86_64.AppImage

# Terminal 2: AirSim
.airsim_ardupilot/airsim/AirSimNH/LinuxNoEditor/AirSimNH.sh

# Terminal 3: ArduPilot SITL (in pixi shell)
cd .airsim_ardupilot/ardupilot
python3 Tools/autotest/sim_vehicle.py -v ArduCopter --model airsim-copter \
  --console --map --out=127.0.0.1:14550 --out=127.0.0.1:14551 \
  --add-param-file=../../scripts/config/ardupilot/airsim.parm
```

## Environment Variables

- `AIRSIM_HOME` - Base directory for all components (default: `./.airsim_ardupilot`)
- `AIRSIM_ENV_RELEASE` - AirSim release tag (default: `v1.8.1`)
- `ARDUPILOT_REPO_URL` - ArduPilot repository URL
- `QGC_URL` - QGroundControl download URL

## Directory Structure

```
.airsim_ardupilot/
├── airsim/
│   ├── AirSimNH/              # Unreal Engine environment
│   └── settings.json          # AirSim configuration
├── qgroundcontrol/
│   └── QGroundControl-x86_64.AppImage
└── ardupilot/
    ├── build/sitl/bin/arducopter
    └── Tools/autotest/sim_vehicle.py

scripts/
├── config/
│   ├── airsim/
│   │   └── settings.json      # AirSim template
│   └── ardupilot/
│       └── airsim.parm        # ArduPilot parameters
├── download-airsim.sh
├── download-qground.sh
├── build-ardupilot-sitl.sh
├── check-simulation.sh
└── run-simulation.sh
```

## Pixi Environment Details

The `simulation` environment defined in `pixi.toml` provides:

### Conda Dependencies
- `python` (3.11-3.12)
- `gcc_linux-64`, `gxx_linux-64` - C/C++ compilers
- `make`, `pkg-config`, `ccache` - Build tools
- `git`, `wget`, `unzip`, `zip`, `rsync` - Utilities

### PyPI Dependencies
- `empy==3.3.4` - Template engine (required by ArduPilot waf)
- `pexpect` - Process automation
- `dronecan` - DroneCAN/UAVCAN support
- `future` - Python 2/3 compatibility
- `pymavlink` - MAVLink protocol library
- `MAVProxy` - MAVLink proxy and command shell
- `pyserial` - Serial communication
- `packaging`, `monotonic` - Utility libraries

## Troubleshooting

### Build Errors

If ArduPilot build fails:
```bash
./scripts/build-ardupilot-sitl.sh --clean
```

### Missing Dependencies

Ensure you're in the Pixi environment:
```bash
pixi shell -e simulation
```

### Settings Not Applied

Re-run the download script to reset settings:
```bash
rm -rf .airsim_ardupilot/airsim/settings.json
./scripts/download-airsim.sh
```

## Notes

- All builds are self-contained within `.airsim_ardupilot/` directory
- No system-wide package installation required
- ArduPilot parameters are automatically loaded on startup
- QGroundControl connects via MAVLink on port 14550
- Additional telemetry output available on port 14551

## License

This project follows the licenses of its components:
- ArduPilot: GPLv3
- AirSim: MIT
- QGroundControl: Apache 2.0 / GPLv3
