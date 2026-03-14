{ stdenvNoCC, kdePackages }:

let
  themeId = "org.custom.jochberg.desktop";
  breezeLaf = "${kdePackages.plasma-workspace}/share/plasma/look-and-feel/org.kde.breeze.desktop";
  wallpaper = builtins.path {
    path = ../../users-hm/Jochberg_Nixos_v2.png;
    name = "background.png";
  };
in
stdenvNoCC.mkDerivation {
  pname = "kde-splash-jochberg";
  version = "1.0";

  dontUnpack = true;

  installPhase = ''
    dir=$out/share/plasma/look-and-feel/${themeId}
    mkdir -p $dir/contents/splash/images

    cp ${./metadata.json} $dir/metadata.json
    cp ${./defaults} $dir/contents/defaults
    cp ${./Splash.qml} $dir/contents/splash/Splash.qml

    # Copy spinner and logo SVGs from Breeze
    cp ${breezeLaf}/contents/splash/images/busywidget.svgz $dir/contents/splash/images/
    cp ${breezeLaf}/contents/splash/images/kde.svgz $dir/contents/splash/images/
    cp ${breezeLaf}/contents/splash/images/plasma.svgz $dir/contents/splash/images/

    # Copy wallpaper as background
    cp ${wallpaper} $dir/contents/splash/images/background.png
  '';
}
