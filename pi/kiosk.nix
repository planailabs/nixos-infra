{ config, pkgs, lib, ... }:

let
  kioskUrl = "https://prometheus.plan.ai";

  browser = pkgs.chromium.override {
    commandLineArgs = [
      "--kiosk"
      "--no-first-run"
      "--disable-infobars"
      "--disable-translate"
      "--disable-features=TranslateUI"
      "--disable-session-crashed-bubble"
      "--disable-restore-session-state"
      "--disable-pinch"
      "--overscroll-history-navigation=0"
      "--autoplay-policy=no-user-gesture-required"
      "--check-for-update-interval=31536000"
    ];
  };

  # Cage is a minimal Wayland kiosk compositor — runs a single fullscreen app
  kioskScript = pkgs.writeShellScriptBin "kiosk" ''
    exec ${pkgs.cage}/bin/cage -- \
      ${browser}/bin/chromium \
        --kiosk \
        --no-first-run \
        --disable-infobars \
        --disable-translate \
        --disable-features=TranslateUI \
        --disable-session-crashed-bubble \
        --disable-restore-session-state \
        --disable-pinch \
        --overscroll-history-navigation=0 \
        --autoplay-policy=no-user-gesture-required \
        --check-for-update-interval=31536000 \
        "${kioskUrl}"
  '';

in
{
  # Disable display manager restart on config changes (matches original)
  systemd.services.display-manager.restartIfChanged = false;

  # Kiosk user (mirrors original structure)
  users.users.kiosk = {
    group = "kiosk";
    extraGroups = [ "video" "input" "seat" ];
    isNormalUser = true;
    home = "/run/kiosk";
    createHome = true;
  };
  users.groups.kiosk = {};

  # seatd — required for rootless Wayland compositors like cage
  services.seatd.enable = true;

  # Auto-login via greetd + cage directly (no full display manager needed)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.cage}/bin/cage -- ${browser}/bin/chromium --kiosk \"${kioskUrl}\"";
        user = "kiosk";
      };
    };
  };

  # Tmpfiles: home dirs and runtime config (matches original pattern)
  systemd.tmpfiles.rules = [
    "d /run/kiosk          0755 kiosk kiosk"
    "d /run/kiosk/.config  0755 kiosk kiosk"
    "d /content            0755 kiosk kiosk"
  ];

  environment.systemPackages = [
    kioskScript
    browser
    pkgs.cage
  ];

  # Cage needs access to DRM/KMS
  hardware.opengl.enable = true;

  # Disable screen blanking / DPMS
  services.xserver.enable = lib.mkDefault false;

  environment.variables = {
    # Force Wayland for Chromium/Electron apps
    NIXOS_OZONE_WL = "1";
    # Prevent cursor theming issues in kiosk
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
