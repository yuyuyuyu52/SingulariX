#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CORE_SCRIPT="$SCRIPT_DIR/platforms/container/nodejs/start.sh"

download_bootstrap_file() {
  url="$1"
  out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
    return $?
  fi
  return 127
}

bootstrap_core_script() {
  [ -f "$CORE_SCRIPT" ] && return 0

  raw_base_url="${SGX_RAW_BASE_URL:-https://raw.githubusercontent.com/yuyuyuyu52/SingulariX/main}"
  core_url="${SGX_CORE_URL:-$raw_base_url/platforms/container/nodejs/start.sh}"
  bootstrap_root="${TMPDIR:-/tmp}/singularix-bootstrap-$$"
  bootstrap_core="$bootstrap_root/platforms/container/nodejs/start.sh"

  mkdir -p "$bootstrap_root/platforms/container/nodejs" 2>/dev/null || return 1
  if download_bootstrap_file "$core_url" "$bootstrap_core" && [ -s "$bootstrap_core" ]; then
    chmod +x "$bootstrap_core" 2>/dev/null || true
    CORE_SCRIPT="$bootstrap_core"
    return 0
  fi
  return 1
}

if [ ! -f "$CORE_SCRIPT" ] && ! bootstrap_core_script; then
  echo "Error: core script not found: $CORE_SCRIPT" >&2
  echo "Please verify the repository structure, or retry the one-liner install command." >&2
  echo "You can also clone the repo manually and run ./singularix.sh" >&2
  exit 1
fi

chmod +x "$CORE_SCRIPT" 2>/dev/null || true

install_sgx_shortcut() {
  launcher="$SCRIPT_DIR/singularix.sh"

  # When running from pipe (bash <(curl ...)), $SCRIPT_DIR points to /dev/fd
  # and the launcher file won't exist. Download and persist it.
  if [ ! -f "$launcher" ]; then
    mkdir -p "$HOME/sgx" 2>/dev/null || return 0
    launcher="$HOME/sgx/singularix.sh"
    if [ ! -f "$launcher" ]; then
      raw_base_url="${SGX_RAW_BASE_URL:-https://raw.githubusercontent.com/yuyuyuyu52/SingulariX/main}"
      download_bootstrap_file "$raw_base_url/singularix.sh" "$launcher" || return 0
      chmod +x "$launcher" 2>/dev/null || true
    fi
  fi

  if [ "$(id -u)" -eq 0 ]; then
    target="/usr/local/bin/sgx"
  else
    target="$HOME/.local/bin/sgx"
  fi

  target_dir=$(dirname "$target")
  mkdir -p "$target_dir" 2>/dev/null || return 0

  if [ -f "$target" ] && grep -Fq "exec sh \"$launcher\" \"\$@\"" "$target"; then
    return 0
  fi

  cat > "$target" <<EOF
#!/bin/sh
exec sh "$launcher" "\$@"
EOF
  chmod +x "$target" 2>/dev/null || return 0

  if [ "$target" = "$HOME/.local/bin/sgx" ] && [ -t 0 ]; then
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *)
        echo "Hint: sgx installed to $target."
        echo "Run first: export PATH=\"$HOME/.local/bin:\$PATH\""
        ;;
    esac
  fi
}

install_sgx_shortcut

has_env_overrides() {
  for key in uuid vlpt vmpt vwpt hypt tupt xhpt vxpt anpt arpt sspt sopt reym cdnym ippz name; do
    eval "value=\${$key:-}"
    if [ -n "$value" ]; then
      return 0
    fi
  done
  return 1
}

stop_managed_processes() {
  if [ -d "$HOME/sgx" ]; then
    pkill -f "$HOME/sgx/xray" >/dev/null 2>&1 || true
    pkill -f "$HOME/sgx/sing-box" >/dev/null 2>&1 || true
  fi
}

is_installed() {
  [ -d "$HOME/sgx" ] && ([ -f "$HOME/sgx/xray" ] || [ -f "$HOME/sgx/sing-box" ])
}

safe_clear() {
  command -v clear >/dev/null 2>&1 && clear || true
}

rand_port() {
  if command -v shuf >/dev/null 2>&1; then
    shuf -i 10000-65535 -n 1
  else
    awk 'BEGIN{srand(); print int(10000 + rand() * 55535)}'
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "unsupported" ;;
  esac
}

run_core() {
  sh "$CORE_SCRIPT" "$@"
}

pause_if_tty() {
  if [ -t 0 ]; then
    printf "Press Enter to continue..."
    read -r _
  fi
}

run_or_warn() {
  action_name="$1"
  shift

  if "$@"; then
    return 0
  fi

  code=$?
  echo "[$action_name] failed, exit code: $code"
  if [ "$code" -eq 127 ]; then
    echo "Hint: missing dependencies (install coreutils curl wget tar unzip openssl)."
  fi
  pause_if_tty
  return "$code"
}

download_file() {
  url="$1"
  out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -L -o "$out" --retry 2 "$url"
    return $?
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -O "$out" --tries=2 "$url"
    return $?
  fi

  return 127
}

run_install_profile() {
  profile="$1"
  stop_managed_processes

  unset vlpt vmpt vwpt hypt tupt xhpt vxpt anpt arpt sspt sopt reym cdnym ippz name uuid || true

  case "$profile" in
    reality)
      export vlpt=443
      ;;
    hy2)
      export hypt="$(rand_port)"
      ;;
    tuic)
      export tupt="$(rand_port)"
      ;;
    ss2022)
      export sspt="$(rand_port)"
      ;;
    vlessws)
      export vwpt="$(rand_port)"
      ;;
    vmessws)
      export vmpt="$(rand_port)"
      ;;
    socks5)
      export sopt="$(rand_port)"
      ;;
    custom)
      ;;
  esac

  if [ "${SGX_AUTO_BBR:-1}" = "1" ]; then
    echo "Install: auto-enabling BBR..."
    enable_bbr || true
  fi

  run_core
}

load_existing_env() {
  [ -f "$HOME/sgx/vlpt" ] && export vlpt="$(cat "$HOME/sgx/vlpt")"
  [ -f "$HOME/sgx/vmpt" ] && export vmpt="$(cat "$HOME/sgx/vmpt")"
  [ -f "$HOME/sgx/vwpt" ] && export vwpt="$(cat "$HOME/sgx/vwpt")"
  [ -f "$HOME/sgx/hypt" ] && export hypt="$(cat "$HOME/sgx/hypt")"
  [ -f "$HOME/sgx/tupt" ] && export tupt="$(cat "$HOME/sgx/tupt")"
  [ -f "$HOME/sgx/xhpt" ] && export xhpt="$(cat "$HOME/sgx/xhpt")"
  [ -f "$HOME/sgx/vxpt" ] && export vxpt="$(cat "$HOME/sgx/vxpt")"
  [ -f "$HOME/sgx/anpt" ] && export anpt="$(cat "$HOME/sgx/anpt")"
  [ -f "$HOME/sgx/arpt" ] && export arpt="$(cat "$HOME/sgx/arpt")"
  [ -f "$HOME/sgx/sspt" ] && export sspt="$(cat "$HOME/sgx/sspt")"
  [ -f "$HOME/sgx/sopt" ] && export sopt="$(cat "$HOME/sgx/sopt")"
  [ -f "$HOME/sgx/reym" ] && export reym="$(cat "$HOME/sgx/reym")"
  [ -f "$HOME/sgx/cdnym" ] && export cdnym="$(cat "$HOME/sgx/cdnym")"
  [ -f "$HOME/sgx/name" ] && export name="$(cat "$HOME/sgx/name")"
  [ -f "$HOME/sgx/uuid" ] && export uuid="$(cat "$HOME/sgx/uuid")"

}

build_subscription() {
  sub_root="$HOME/sgx/sub"
  src_file="$HOME/sgx/jh.txt"
  base64_file="$sub_root/index"
  sub_port=12345
  converter_url="${SUBCONVERTER_URL:-https://api.v1.mk/sub}"

  if [ ! -s "$src_file" ]; then
    echo "Subscription not generated (jh.txt is empty)."
    return
  fi

  mkdir -p "$sub_root"
  if base64 --help 2>/dev/null | grep -q -- '-w'; then
    base64 -w0 "$src_file" > "$base64_file"
  else
    base64 "$src_file" | tr -d '\n' > "$base64_file"
  fi

  if [ -f "$HOME/sgx/uuid" ]; then
    sub_path=$(head -c 8 "$HOME/sgx/uuid")
  else
    sub_path="default"
  fi
  [ -z "$sub_path" ] && sub_path="default"

  mkdir -p "$sub_root/$sub_path"
  cp "$src_file" "$sub_root/$sub_path/raw"
  cp "$base64_file" "$sub_root/$sub_path/base64"
  cp "$base64_file" "$sub_root/$sub_path/config"

  # Try to pre-generate converted subscription files. If conversion fails,
  # keep online conversion links as fallback.
  url_encode() {
    input="$1"
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$input" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=''))
PY
      return
    fi
    # Minimal fallback when python3 is unavailable.
    echo "$input" | sed 's/%/%25/g; s/:/%3A/g; s/\//%2F/g; s/?/%3F/g; s/&/%26/g; s/=/%3D/g; s/\[/%5B/g; s/\]/%5D/g'
  }

  fetch_quiet() {
    url="$1"
    out="$2"
    if command -v curl >/dev/null 2>&1; then
      curl -LfsS --retry 1 -o "$out" "$url" >/dev/null 2>&1
      return $?
    fi
    if command -v wget >/dev/null 2>&1; then
      wget -qO "$out" "$url"
      return $?
    fi
    return 127
  }

  is_valid_converted_file() {
    f="$1"
    [ -s "$f" ] || return 1
    bytes=$(wc -c < "$f" 2>/dev/null || echo 0)
    [ "$bytes" -ge 64 ] || return 1
    if grep -Eqi 'error|bad gateway|forbidden|not found|<!doctype html|<html' "$f"; then
      return 1
    fi
    return 0
  }

  if command -v python3 >/dev/null 2>&1; then
    if ! pgrep -f "python3 -m http.server $sub_port --directory $sub_root" >/dev/null 2>&1; then
      nohup python3 -m http.server "$sub_port" --directory "$sub_root" >/dev/null 2>&1 &
    fi

    if [ -f "$HOME/sgx/server_ip.log" ]; then
      server_ip=$(cat "$HOME/sgx/server_ip.log")
    elif command -v curl >/dev/null 2>&1; then
      server_ip=$(curl -s4m5 icanhazip.com || curl -s6m5 icanhazip.com || true)
    else
      server_ip=$(wget -qO- -4 icanhazip.com 2>/dev/null || wget -qO- -6 icanhazip.com 2>/dev/null || true)
    fi

    server_ip=$(echo "$server_ip" | tr -d '[:space:]')
    if echo "$server_ip" | grep -q ':' && ! echo "$server_ip" | grep -q '^\['; then
      server_ip="[$server_ip]"
    fi

    if [ -n "$server_ip" ]; then
      raw_url="http://$server_ip:$sub_port/$sub_path/raw"
      base64_url="http://$server_ip:$sub_port/$sub_path/base64"
      base64_url_enc=$(url_encode "$base64_url")

      singbox_convert_url="$converter_url?target=singbox&new_name=true&url=$base64_url_enc&insert=false&emoji=true"
      clash_convert_url="$converter_url?target=clash&new_name=true&url=$base64_url_enc&insert=false&emoji=true"

      singbox_local="$sub_root/$sub_path/singbox"
      clash_local="$sub_root/$sub_path/clash"
      rm -f "$singbox_local" "$clash_local" >/dev/null 2>&1 || true

      if fetch_quiet "$singbox_convert_url" "$singbox_local" && is_valid_converted_file "$singbox_local"; then
        singbox_url="http://$server_ip:$sub_port/$sub_path/singbox"
      else
        rm -f "$singbox_local" >/dev/null 2>&1 || true
        singbox_url="$singbox_convert_url"
      fi

      if fetch_quiet "$clash_convert_url" "$clash_local" && is_valid_converted_file "$clash_local"; then
        clash_url="http://$server_ip:$sub_port/$sub_path/clash"
      else
        rm -f "$clash_local" >/dev/null 2>&1 || true
        clash_url="$clash_convert_url"
      fi

      echo "Subscribe (Base64): $base64_url"
      echo "Subscribe (ShadowBox/Sing-box): $singbox_url"
      echo "Subscribe (Clash): $clash_url"
      echo "Raw URI: $raw_url"
    else
      echo "Subscription file generated: $sub_root/$sub_path/base64"
      echo "ShadowBox/Sing-box convert URL: $converter_url?target=singbox&new_name=true&url=<Base64-URL-encoded>&insert=false&emoji=true"
      echo "Clash convert URL: $converter_url?target=clash&new_name=true&url=<Base64-URL-encoded>&insert=false&emoji=true"
    fi
  else
    echo "python3 not found. Subscription file generated: $sub_root/$sub_path/base64"
    echo "Raw node file: $sub_root/$sub_path/raw"
    echo "Install python3 and run 'list' again to output accessible subscription URLs."
  fi
}

show_list() {
  safe_clear
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo "SingulariX - Nodes & Status"
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  if [ -f "$HOME/sgx/jh.txt" ]; then
    cat "$HOME/sgx/jh.txt"
  else
    echo "No node list generated (jh.txt not found)."
  fi
  echo
  build_subscription
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  if [ -t 0 ] && [ "${SGX_NO_PAUSE:-}" != "1" ]; then
    printf "Press Enter to return to menu..."
    read -r _
  fi
}

restart_services() {
  if ! is_installed; then
    echo "Install directory not found, cannot restart."
    sleep 1
    return
  fi
  echo "Restarting kernel processes..."
  stop_managed_processes
  load_existing_env
  run_core
}

upgrade_xray() {
  arch="$(detect_arch)"
  case "$arch" in
    amd64) xarch="64" ;;
    arm64) xarch="arm64-v8a" ;;
    *)
      echo "Current architecture does not support auto-upgrade for Xray."
      return
      ;;
  esac

  if ! command -v unzip >/dev/null 2>&1; then
    echo "Missing unzip, cannot extract Xray. Please install unzip first."
    return
  fi

  url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$xarch.zip"
  out="$HOME/sgx/xray.zip"
  echo "Upgrading Xray..."
  if ! download_file "$url" "$out"; then
    echo "Failed to download Xray. Check network or curl/wget availability."
    return
  fi
  unzip -o "$out" xray -d "$HOME/sgx" >/dev/null 2>&1
  chmod +x "$HOME/sgx/xray"
  rm -f "$out"
  echo "Xray upgrade complete."
}

upgrade_singbox() {
  arch="$(detect_arch)"
  if [ "$arch" = "unsupported" ]; then
    echo "Current architecture does not support auto-upgrade for Sing-box."
    return
  fi

  sver=$( (command -v curl >/dev/null 2>&1 && curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' | head -n1) || (command -v wget >/dev/null 2>&1 && wget -qO- https://api.github.com/repos/SagerNet/sing-box/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' | head -n1) )
  [ -z "$sver" ] && sver="1.11.1"

  url="https://github.com/SagerNet/sing-box/releases/download/v$sver/sing-box-$sver-linux-$arch.tar.gz"
  out="$HOME/sgx/sing-box.tar.gz"
  echo "Upgrading Sing-box..."
  if ! download_file "$url" "$out"; then
    echo "Failed to download Sing-box. Check network or curl/wget availability."
    return
  fi
  tar -xzf "$out" -C "$HOME/sgx" --strip-components=1 "sing-box-$sver-linux-$arch/sing-box"
  chmod +x "$HOME/sgx/sing-box"
  rm -f "$out"
  echo "Sing-box upgrade complete."
}

upgrade_cores() {
  if ! is_installed; then
    echo "Install directory not found, cannot upgrade."
    sleep 1
    return
  fi

  safe_clear
  echo "1) Upgrade Xray"
  echo "2) Upgrade Sing-box"
  echo "3) Upgrade all"
  printf "Select [1-3]: "
  read -r up_choice
  case "$up_choice" in
    1) upgrade_xray ;;
    2) upgrade_singbox ;;
    3) upgrade_xray; upgrade_singbox ;;
    *) echo "Invalid choice" ;;
  esac
  printf "Press Enter to return to menu..."
  read -r _
}

uninstall_all() {
  if ! is_installed; then
    echo "Install directory not found, nothing to uninstall."
    sleep 1
    return
  fi
  printf "Confirm full uninstall (delete $HOME/sgx)? [y/N]: "
  read -r answer
  case "$answer" in
    y|Y)
      stop_managed_processes
      rm -rf "$HOME/sgx"
      rm -f /usr/local/bin/sgx "$HOME/.local/bin/sgx" 2>/dev/null || true
      echo "Uninstall complete."
      ;;
    *)
      echo "Uninstall cancelled."
      ;;
  esac
  sleep 1
}

enable_bbr() {
  echo "Checking and enabling BBR..."
  if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
    echo "BBR is already enabled."
    sleep 1
    return
  fi

  if [ "$(id -u)" -ne 0 ]; then
    echo "Not running as root, cannot write to /etc/sysctl.conf."
    echo "Please run the script with sudo."
    sleep 2
    return
  fi

  grep -q '^net.core.default_qdisc=fq' /etc/sysctl.conf 2>/dev/null || echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
  grep -q '^net.ipv4.tcp_congestion_control=bbr' /etc/sysctl.conf 2>/dev/null || echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
  sysctl -p >/dev/null 2>&1 || true

  if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
    echo "BBR enabled successfully."
  else
    echo "Failed to enable BBR. Kernel version >= 4.9 required."
  fi
  sleep 2
}

check_ip_purity() {
  echo "Checking IP purity and streaming unlock..."

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "curl/wget not found, cannot run check."
    pause_if_tty
    return
  fi

  tmp_script="/tmp/sgx-ipcheck-$$.sh"
  fetched=0

  for url in \
    "https://raw.githubusercontent.com/spiritLHLS/ecs/main/ipcheck.sh" \
    "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh"
  do
    if command -v curl >/dev/null 2>&1; then
      if curl -L -s "$url" -o "$tmp_script" && [ -s "$tmp_script" ]; then
        first_line=$(head -n 1 "$tmp_script" 2>/dev/null || true)
        if ! echo "$first_line" | grep -qi '^404:'; then
          fetched=1
          break
        fi
      fi
    else
      if wget -qO "$tmp_script" "$url" && [ -s "$tmp_script" ]; then
        first_line=$(head -n 1 "$tmp_script" 2>/dev/null || true)
        if ! echo "$first_line" | grep -qi '^404:'; then
          fetched=1
          break
        fi
      fi
    fi
  done

  if [ "$fetched" -ne 1 ]; then
    echo "Failed to download check script (upstream unavailable). Try again later."
    rm -f "$tmp_script" >/dev/null 2>&1 || true
    pause_if_tty
    return
  fi

  chmod +x "$tmp_script" >/dev/null 2>&1 || true
  if command -v bash >/dev/null 2>&1; then
    bash "$tmp_script" || echo "Check script failed. Try again later."
  else
    sh "$tmp_script" || echo "Check script failed. Try again later."
  fi
  rm -f "$tmp_script" >/dev/null 2>&1 || true
  pause_if_tty
}

# Keep non-interactive behavior for automation and CI.
if [ "$#" -gt 0 ]; then
  export SGX_NO_PAUSE=1
  case "$1" in
    list)
      run_or_warn "Show nodes & status" show_list
      exit $?
      ;;
    res)
      run_or_warn "Restart services" restart_services
      exit $?
      ;;
    upx)
      run_or_warn "Upgrade Xray" upgrade_xray
      exit $?
      ;;
    ups)
      run_or_warn "Upgrade Sing-box" upgrade_singbox
      exit $?
      ;;
    del)
      run_or_warn "Uninstall" uninstall_all
      exit $?
      ;;
    *)
      exec sh "$CORE_SCRIPT" "$@"
      ;;
  esac
fi

if has_env_overrides || [ ! -t 0 ]; then
  exec sh "$CORE_SCRIPT" "$@"
fi

print_menu() {
  safe_clear
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo "SingulariX Menu"
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo " [1] Install VLESS-Reality (TCP)"
  echo " [2] Install Hysteria2"
  echo " [3] Install TUIC"
  echo " [4] Install Shadowsocks-2022"
  echo " [5] Install VLESS-WS"
  echo " [6] Install VMess-WS"
  echo " [7] Install SOCKS5"
  echo "-----------------------------------------------------------"
  echo " [12] Enable BBR"
  echo " [13] Check IP purity"
  echo "-----------------------------------------------------------"
  if is_installed; then
    echo " [8] Show nodes & status"
    echo " [9] Restart services"
    echo " [10] Upgrade kernel (Xray/Sing-box)"
    echo " [11] Full uninstall"
  else
    echo " [8] Show nodes & status (not installed)"
    echo " [9] Restart services (not installed)"
    echo " [10] Upgrade kernel (not installed)"
    echo " [11] Full uninstall (not installed)"
  fi
  echo " [0] Exit"
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

ensure_reinstall_if_running() {
  if pgrep -f "$HOME/sgx/xray|$HOME/sgx/sing-box" >/dev/null 2>&1; then
    printf "Running instance detected. Stop and reinstall with new config? [y/N]: "
    read -r answer
    case "$answer" in
      y|Y)
        stop_managed_processes
        ;;
      *)
        echo "Reinstall cancelled. Showing current status instead."
        run_core
        exit 0
        ;;
    esac
  fi
}

while true; do
  print_menu
  printf "Select [0-13]: "
  read -r choice

  case "$choice" in
    1)
      ensure_reinstall_if_running
      if run_or_warn "Install Reality" run_install_profile reality; then
        exit 0
      fi
      ;;
    2)
      ensure_reinstall_if_running
      if run_or_warn "Install Hy2" run_install_profile hy2; then
        exit 0
      fi
      ;;
    3)
      ensure_reinstall_if_running
      if run_or_warn "Install TUIC" run_install_profile tuic; then
        exit 0
      fi
      ;;
    4)
      ensure_reinstall_if_running
      if run_or_warn "Install Shadowsocks-2022" run_install_profile ss2022; then
        exit 0
      fi
      ;;
    5)
      ensure_reinstall_if_running
      if run_or_warn "Install VLESS-WS" run_install_profile vlessws; then
        exit 0
      fi
      ;;
    6)
      ensure_reinstall_if_running
      if run_or_warn "Install VMess-WS" run_install_profile vmessws; then
        exit 0
      fi
      ;;
    7)
      ensure_reinstall_if_running
      if run_or_warn "Install SOCKS5" run_install_profile socks5; then
        exit 0
      fi
      ;;
    8)
      if is_installed; then
        run_or_warn "Show nodes & status" show_list || true
      else
        echo "Not installed yet. No nodes to show."
        sleep 1
      fi
      ;;
    9)
      if run_or_warn "Restart services" restart_services; then
        exit 0
      fi
      ;;
    10)
      run_or_warn "Upgrade kernel" upgrade_cores || true
      ;;
    11)
      run_or_warn "Uninstall" uninstall_all || true
      ;;
    12)
      run_or_warn "Enable BBR" enable_bbr || true
      ;;
    13)
      run_or_warn "Check IP purity" check_ip_purity || true
      ;;
    0)
      exit 0
      ;;
    *)
      echo "Invalid input, please try again."
      sleep 1
      ;;
  esac
done
