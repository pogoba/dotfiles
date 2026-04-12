{
  lib,
  stdenv,
  libtirpc,
  fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "lmbench";
  version = "941a0dcc";

  # We use the intel repo as they have fixed some problems
  src = fetchFromGitHub {
    owner = "intel";
    repo = pname;
    rev = "941a0dcc0e7bdd9bb0dee05d7f620e77da8c43af";
    sha256 = "sha256-SzwplRBO3V0R3m3p15n71ivYBMGoLsajFK2TapYxdqk=";
  };

  postPatch = ''
    sed -i "s@/bin/rm@rm@g" $(find . -name Makefile)
  '';

  buildInputs = [ libtirpc ];
  patches = [ ./fix-install.patch ./gcc-14.patch ];

  hardeningDisable = [ "all" ];

  enableParallelBuilding = false;

  preBuild = ''
    makeFlagsArray+=(
      -C src
      BASE=$out
      CFLAGS=-Wno-implicit-int
      CPPFLAGS=-I${libtirpc.dev}/include/tirpc
      LDFLAGS=-ltirpc
      CC=$CC
      AR=$AR
    )
  '';

  meta = {
    description = "lmbench";
    homepage = "https://github.com/intel/lmbench";
    maintainers = with lib.maintainers; [ pogobanane ];
    platforms = lib.platforms.all;
    license = lib.licenses.gpl2Plus;
  };
}
