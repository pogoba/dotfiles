{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, meson
, ninja
, pkg-config
, innoextract
, findutils
, openssl
, libusb1
, libcap
, libseccomp
, glib
, dbus
, libfprint-tod
, systemdMinimal
, gusb
, json-glib
}:

let
  driverDlls = stdenv.mkDerivation {
    name = "synatudor-driver-dlls";

    src = fetchurl {
      url = "https://download.lenovo.com/consumer/mobiles/74ti04afkkxbyyb0.exe";
      hash = "sha256-J7IR7uP5c7Lltwgj1vt8aTlIdoOaueLpqF8UuM4QCO4=";
      name = "driver-installer.exe";
    };

    nativeBuildInputs = [ innoextract findutils ];

    unpackPhase = ''
      mkdir -p windrv
      innoextract -d windrv $src
    '';

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out
      for dll in synaFpAdapter139.dll synaWudfBioUsb139.dll; do
        dllPath=$(find windrv -name "$dll" -print -quit)
        if [ -z "$dllPath" ]; then
          echo "ERROR: DLL $dll not found in extracted files"
          exit 1
        fi
        cp "$dllPath" "$out/"
      done
    '';
  };
in
stdenv.mkDerivation {
  pname = "synatudor";
  version = "unstable-2026-03-13";

  src = fetchFromGitHub {
    owner = "MichaelNeilM";
    repo = "synaTudor-00fd";
    rev = "ba37b52546cfe888132f749b7903d27b10beb81a";
    hash = "sha256-x8AfbID3MvWw880v7IzjuBc5eO42N5RGLSC15SUE1Wg=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    openssl
    libusb1
    libcap
    libseccomp
    glib
    dbus
    libfprint-tod
    systemdMinimal
    gusb
    json-glib
  ];

  postPatch = ''
    # Fix hardcoded install directory
    substituteInPlace meson.build \
      --replace-fail "INSTALL_DIR = '/usr/bin/tudor'" \
                     "INSTALL_DIR = get_option('prefix') / 'lib/tudor'"

    # Replace download custom_target with pre-extracted DLLs
    substituteInPlace libtudor/meson.build \
      --replace-fail \
        "input: ['download_driver.sh', 'installer.sha']," \
        "" \
      --replace-fail \
        "command: [find_program('bash'), '@INPUT0@', '@INPUT1@', '@PRIVATE_DIR@', '@OUTDIR@'] + driver_dll_names" \
        "command: ['cp', '${driverDlls}/synaFpAdapter139.dll', '${driverDlls}/synaWudfBioUsb139.dll', '@OUTDIR@']"

    # Fix systemd service install path
    substituteInPlace tudor-host-launcher/meson.build \
      --replace-fail "install_dir: '/usr/lib/systemd/system/'" \
                     "install_dir: get_option('prefix') / 'lib/systemd/system'"

    # Fix dbus config and service paths
    substituteInPlace tudor-host-launcher/meson.build \
      --replace-fail "dbus_dep.get_variable(pkgconfig: 'datadir') / 'dbus-1/system.d'" \
                     "get_option('prefix') / 'share/dbus-1/system.d'" \
      --replace-fail "dbus_dep.get_variable(pkgconfig: 'system_bus_services_dir')" \
                     "get_option('prefix') / 'share/dbus-1/system-services'"

    # Fix udev rules path and libfprint-tod driver install path,
    # and add missing libfprint-2 include dir (the tod-1 pkg-config only
    # includes the tod-1/ subdir, but headers there reference fp-image.h
    # from the parent libfprint-2/ include dir)
    substituteInPlace libfprint-tod/meson.build \
      --replace-fail "udev_dep.get_variable(pkgconfig: 'udevdir')" \
                     "get_option('prefix') / 'lib/udev/rules.d'" \
      --replace-fail "libfprint_tod_dep.get_variable(pkgconfig: 'tod_driversdir')" \
                     "get_option('prefix') / 'lib/libfprint-2/tod-1'" \
      --replace-fail "c_args: ['-D_GNU_SOURCE', '-Wno-missing-braces']," \
                     "c_args: ['-D_GNU_SOURCE', '-Wno-missing-braces', '-I${libfprint-tod}/include/libfprint-2', '-I${glib.dev}/include/gio-unix-2.0'],"

    # Fix hardcoded /sbin/tudor sandbox pivot_root path
    substituteInPlace tudor-host/src/sandbox.c \
      --replace-fail '"/sbin/tudor"' '"'"$out/lib/tudor"'"'

    # Fix systemd service ExecStart/WorkingDirectory paths
    substituteInPlace tudor-host-launcher/tudor-host-launcher.service \
      --replace-fail "/sbin/tudor/tudor_host_launcher" "$out/lib/tudor/tudor_host_launcher" \
      --replace-fail "WorkingDirectory=/sbin/tudor/" "WorkingDirectory=$out/lib/tudor/"
  '';

  passthru = {
    driverPath = "/lib/libfprint-2/tod-1";
    inherit driverDlls;
  };

  meta = with lib; {
    description = "Linux driver for Synaptics fingerprint sensor 06cb:00fd";
    homepage = "https://github.com/MichaelNeilM/synaTudor-00fd";
    license = licenses.lgpl21;
    platforms = [ "x86_64-linux" ];
  };
}
