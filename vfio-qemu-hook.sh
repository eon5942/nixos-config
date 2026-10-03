#!/usr/bin/env bash
# libvirt QEMU hook: dynamically hand the NVIDIA dGPU (01:00.0 + its audio
# function 01:00.1) to the Windows VM and return it to the host afterwards.
#
# libvirt invokes this as:
#   /etc/libvirt/hooks/qemu <guest> <operation> <sub_operation>
#
# Only the VM named `win11` is affected; every other guest is ignored.
#
# It can also be run by hand to test the handoff:
#   doas ./vfio-qemu-hook.sh win11 prepare   # host -> VM (bind to vfio-pci)
#   doas ./vfio-qemu-hook.sh win11 release   # VM -> host (return to nvidia)

set -uo pipefail

GUEST_NAME="${1:-}"
OPERATION="${2:-}"

if [ "$GUEST_NAME" != "win11" ]; then
  exit 0
fi

GPU_PCI="0000:01:00.0"
AUDIO_PCI="0000:01:00.1"
DEVICES=("$GPU_PCI" "$AUDIO_PCI")

bind_to_vfio() {
  modprobe vfio-pci
  for dev in "${DEVICES[@]}"; do
    local devpath="/sys/bus/pci/devices/$dev"
    echo "vfio-pci" > "$devpath/driver_override"
    if [ -e "$devpath/driver" ]; then
      echo "$dev" > "$devpath/driver/unbind" 2>/dev/null || true
    fi
    echo "$dev" > /sys/bus/pci/drivers_probe
  done
}

return_to_host() {
  for dev in "${DEVICES[@]}"; do
    local devpath="/sys/bus/pci/devices/$dev"
    echo "" > "$devpath/driver_override"
    if [ -e "/sys/bus/pci/drivers/vfio-pci/$dev" ]; then
      echo "$dev" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
    fi
    echo "$dev" > /sys/bus/pci/drivers_probe
  done
  modprobe snd_hda_intel 2>/dev/null || true
}

case "$OPERATION" in
  prepare|start)
    bind_to_vfio
    ;;
  release|stopped)
    return_to_host
    ;;
esac

exit 0
