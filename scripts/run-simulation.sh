#!/usr/bin/env bash
set -euo pipefail

# Simple runner for AirSim + ArduPilot SITL + QGroundControl
# Usage:
#   ./scripts/run-simulation.sh
#   ./scripts/run-simulation.sh --no-display

###############################################################################
# Argument parsing
###############################################################################
NO_DISPLAY=0

while [[ ${1:-} == --* ]]; do
  case "$1" in
    --no-display)
      NO_DISPLAY=1
      shift
      ;;
    --help)
      cat <<HELP
Usage: $0 [options]
  --no-display   Run AirSim in NoDisplay mode (no graphics)
  --help         Show this help

Environment variables:
  AIRSIM_HOME    Base directory (default: ./.airsim_ardupilot)
HELP
      exit 0
      ;;
    *)
      echo "[run-simulation] Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

###############################################################################
# Paths
###############################################################################
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
AIRSIM_HOME=${AIRSIM_HOME:-"${PROJECT_ROOT}/.airsim_ardupilot"}

SETTINGS_FILE="${AIRSIM_HOME}/airsim/settings.json"
QGC_APPIMAGE="${AIRSIM_HOME}/qgroundcontrol/QGroundControl-x86_64.AppImage"
AIRSIM_BINARY="${AIRSIM_HOME}/airsim/AirSimNH/LinuxNoEditor/AirSimNH.sh"
ARDUPILOT_DIR="${AIRSIM_HOME}/ardupilot"
SIM_VEHICLE="${ARDUPILOT_DIR}/Tools/autotest/sim_vehicle.py"

###############################################################################
# Pre-flight checks
###############################################################################
echo "[run-simulation] Checking components..."

[[ -d "${AIRSIM_HOME}" ]] || { echo "ERROR: AIRSIM_HOME not found: ${AIRSIM_HOME}" >&2; exit 1; }
[[ -f "${SETTINGS_FILE}" ]] || { echo "ERROR: settings.json not found: ${SETTINGS_FILE}" >&2; exit 1; }
[[ -f "${QGC_APPIMAGE}" ]] || { echo "ERROR: QGroundControl not found: ${QGC_APPIMAGE}" >&2; exit 1; }
[[ -x "${QGC_APPIMAGE}" ]] || chmod +x "${QGC_APPIMAGE}"
[[ -f "${AIRSIM_BINARY}" ]] || { echo "ERROR: AirSim binary not found: ${AIRSIM_BINARY}" >&2; exit 1; }
[[ -x "${AIRSIM_BINARY}" ]] || chmod +x "${AIRSIM_BINARY}"
[[ -f "${SIM_VEHICLE}" ]] || { echo "ERROR: sim_vehicle.py not found: ${SIM_VEHICLE}" >&2; exit 1; }

command -v python3 >/dev/null || { echo "ERROR: python3 not found" >&2; exit 1; }

echo "[run-simulation] All components ready."

###############################################################################
# Update ViewMode in settings.json
###############################################################################
if [[ ${NO_DISPLAY} -eq 1 ]]; then
  echo "[run-simulation] Setting ViewMode to NoDisplay..."
  sed -i 's/"ViewMode": "[^"]*"/"ViewMode": "NoDisplay"/' "${SETTINGS_FILE}"
else
  echo "[run-simulation] Setting ViewMode to FlyWithMe..."
  sed -i 's/"ViewMode": "[^"]*"/"ViewMode": "FlyWithMe"/' "${SETTINGS_FILE}"
fi

###############################################################################
# Cleanup handler
###############################################################################
PIDS=()

cleanup() {
  echo ""
  echo "[run-simulation] Shutting down..."
  
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      echo "[run-simulation] Stopping process $pid"
      kill "$pid" 2>/dev/null || true
    fi
  done
  
  # Extra cleanup for any orphaned processes
  pkill -f "AirSimNH.sh" 2>/dev/null || true
  pkill -f "QGroundControl" 2>/dev/null || true
  pkill -f "arducopter.*airsim-copter" 2>/dev/null || true
  
  echo "[run-simulation] Cleanup complete."
  exit 0
}

trap cleanup EXIT INT TERM

###############################################################################
# Start components
###############################################################################

echo ""
echo "========================================"
echo "  Starting Simulation Environment"
echo "========================================"
echo ""

# 1. Start QGroundControl (background)
echo "[run-simulation] Starting QGroundControl..."
"${QGC_APPIMAGE}" >/dev/null 2>&1 &
PIDS+=($!)
echo "[run-simulation] QGroundControl started (PID: ${PIDS[-1]})"
sleep 2

# 2. Start AirSim (background)
echo "[run-simulation] Starting AirSim (AirSimNH)..."
AIRSIM_ARGS="-ResX=1280 -ResY=720 -windowed"
"${AIRSIM_BINARY}" ${AIRSIM_ARGS} >/dev/null 2>&1 &
PIDS+=($!)
echo "[run-simulation] AirSim started (PID: ${PIDS[-1]})"
echo "[run-simulation] Waiting for AirSim to initialize..."
sleep 8

# 3. Start ArduPilot SITL (foreground)
echo "[run-simulation] Starting ArduPilot SITL..."
echo ""

cd "${ARDUPILOT_DIR}"

# Load parameter file if available
PARAM_FILE="${PROJECT_ROOT}/scripts/config/ardupilot/airsim.parm"
if [[ -f "${PARAM_FILE}" ]]; then
  echo "[run-simulation] Using parameter file: ${PARAM_FILE}"
  PARAM_ARG="--add-param-file=${PARAM_FILE}"
else
  echo "[run-simulation] Warning: Parameter file not found: ${PARAM_FILE}"
  PARAM_ARG=""
fi

# Run sim_vehicle.py with proper arguments
python3 "${SIM_VEHICLE}" \
  -v ArduCopter \
  --model airsim-copter \
  --console \
  --map \
  --out=127.0.0.1:14550 \
  --out=127.0.0.1:14551 \
  ${PARAM_ARG}

# If we reach here, sim_vehicle.py has exited
echo ""
echo "[run-simulation] ArduPilot SITL exited."
