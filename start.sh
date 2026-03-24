cat > $PREFIX/bin/start << 'EOF'
#!/bin/bash

# Kill open X11 processes
kill -9 $(pgrep -f "termux.x11") 2>/dev/null

# Get the phone manufacturer
MANUFACTURER=$(getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')

# Check the manufacturer
if [[ "$MANUFACTURER" == "samsung" ]]; then
    [ -d ~/.config/pulse ] && rm -rf ~/.config/pulse
    LD_PRELOAD=/system/lib64/libskcodec.so pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
else
   pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
fi

# Set audio server
export PULSE_SERVER=127.0.0.1

# Prepare termux-x11 session
export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :0 >/dev/null &

# Wait a bit until termux-x11 gets started.
sleep 3

# Launch Termux X11 main activity
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

# Function to check the GPU type
gpu_check() {
    # Attempt to detect GPU using getprop
    gpu_egl=$(getprop ro.hardware.egl)
    gpu_vulkan=$(getprop ro.hardware.vulkan)

    # Combine unique GPU information
    detected_gpu="$(echo -e "$gpu_egl\n$gpu_vulkan" | sort -u | tr '\n' ' ' | sed 's/ $//')"

    if echo "$detected_gpu" | grep -iq "adreno"; then
        echo "GPU detected: $detected_gpu"
        MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2 LIBGL_DRI3_DISABLE=1 virgl_test_server_android & > /dev/null 2>&1
    elif echo "$detected_gpu" | grep -iq "mali"; then
        echo "GPU detected: $detected_gpu"
        MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2 LIBGL_DRI3_DISABLE=1 virgl_test_server_android --angle-gl & > /dev/null 2>&1
    else
        echo "Unknown GPU type detected: $detected_gpu"
        exit 1
    fi
}

# Run the GPU check function
gpu_check

# Run XFCE4 Desktop
dbus-daemon --session --address=unix:path=$PREFIX/var/run/dbus-session &
env DISPLAY=:0 GALLIUM_DRIVER=virpipe dbus-launch --exit-with-session xfce4-session & > /dev/null 2>&1

exit 0
EOF

chmod +x $PREFIX/bin/start
