{ stdenv, lib, fetchFromGitHub
, makeWrapper, unzip, which, writeTextFile
, curl, tzdata, gdb, darwin, git, callPackage
, targetPackages, fetchpatch, bash
, dmdBootstrap ? callPackage ./bootstrap.nix { }
, HOST_DMD ? "${dmdBootstrap}/bin/dmd"
, version ? "2.094.2"
, dmdSha256 ? "0fbsah3kvvyggzx0mybg7x900rlz5kb73x1ndbjlp48c5p21rkv8"
, druntimeSha256 ? "06v9fd7sb8micsywy25czmrskas7rlf3ckvf7qpyz58dbx2v8mbs"
, phobosSha256 ? "0rxm0x4ppnygp8p0fg3gjl42cs75k2ij6fh7f0l8rmbq16z386bw"
}:

let

  dmdConfFile = writeTextFile {
      name = "dmd.conf";
      text = (lib.generators.toINI {} {
        Environment = {
          DFLAGS = ''-I@out@/include/dmd -L-L@out@/lib -fPIC ${stdenv.lib.optionalString (!targetPackages.stdenv.cc.isClang) "-L--export-dynamic"}'';
        };
      });
  };

in

stdenv.mkDerivation rec {
  pname = "dmd";
  inherit version;

  enableParallelBuilding = true;

  srcs = [
  (fetchFromGitHub {
    owner = "dlang";
    repo = "dmd";
    rev = "v${version}";
    sha256 = dmdSha256;
    name = "dmd";
  })
  (fetchFromGitHub {
    owner = "dlang";
    repo = "druntime";
    rev = "v${version}";
    sha256 = druntimeSha256;
    name = "druntime";
  })
  (fetchFromGitHub {
    owner = "dlang";
    repo = "phobos";
    rev = "v${version}";
    sha256 = phobosSha256;
    name = "phobos";
  })
  ];

  sourceRoot = ".";

  # https://issues.dlang.org/show_bug.cgi?id=19553
  hardeningDisable = [ "fortify" ];

  postUnpack = ''
      patchShebangs .
  '';

  postPatch = ''
      substituteInPlace dmd/test/dshell/test6952.d --replace "/usr/bin/env bash" "${bash}/bin/bash"
  ''
  + stdenv.lib.optionalString stdenv.hostPlatform.isLinux ''
      substituteInPlace phobos/std/socket.d --replace "assert(ih.addrList[0] == 0x7F_00_00_01);" ""
  ''
  + stdenv.lib.optionalString stdenv.hostPlatform.isDarwin ''
      substituteInPlace phobos/std/socket.d --replace "foreach (name; names)" "names = []; foreach (name; names)"
  '';

  nativeBuildInputs = [ makeWrapper unzip which gdb git ]

  ++ stdenv.lib.optional stdenv.hostPlatform.isDarwin (with darwin.apple_sdk.frameworks; [
    Foundation
  ]);

  buildInputs = [ curl tzdata ];

  bits = builtins.toString stdenv.hostPlatform.parsed.cpu.bits;
  osname = if stdenv.hostPlatform.isDarwin then
    "osx"
  else
    stdenv.hostPlatform.parsed.kernel.name;
  top = "$(echo $NIX_BUILD_TOP)";
  pathToDmd = "${top}/dmd/generated/${osname}/release/${bits}/dmd";

  # Buid and install are based on http://wiki.dlang.org/Building_DMD
  buildPhase = ''
      cd dmd
      make -j$NIX_BUILD_CORES -f posix.mak INSTALL_DIR=$out BUILD=release ENABLE_RELEASE=1 PIC=1 HOST_DMD=${HOST_DMD}
      cd ../druntime
      make -j$NIX_BUILD_CORES -f posix.mak BUILD=release ENABLE_RELEASE=1 PIC=1 INSTALL_DIR=$out DMD=${pathToDmd}
      cd ../phobos
      echo ${tzdata}/share/zoneinfo/ > TZDatabaseDirFile
      echo ${curl.out}/lib/libcurl${stdenv.hostPlatform.extensions.sharedLibrary} > LibcurlPathFile
      make -j$NIX_BUILD_CORES -f posix.mak BUILD=release ENABLE_RELEASE=1 PIC=1 INSTALL_DIR=$out DMD=${pathToDmd} DFLAGS="-version=TZDatabaseDir -version=LibcurlPath -J$(pwd)"
      cd ..
  '';

  doCheck = true;

  # NOTE: Purity check is disabled for checkPhase because it doesn't fare well
  # with the DMD linker. See https://github.com/NixOS/nixpkgs/issues/97420
  checkPhase = ''
    cd dmd
    NIX_ENFORCE_PURITY= \
      make -j$NIX_BUILD_CORES -C test -f Makefile PIC=1 CC=$CXX DMD=${pathToDmd} BUILD=release SHELL=$SHELL

    cd ../druntime
    NIX_ENFORCE_PURITY= \
      make -j$NIX_BUILD_CORES -f posix.mak unittest PIC=1 DMD=${pathToDmd} BUILD=release

    cd ../phobos
    NIX_ENFORCE_PURITY= \
      make -j$NIX_BUILD_CORES -f posix.mak unittest BUILD=release ENABLE_RELEASE=1 PIC=1 DMD=${pathToDmd} DFLAGS="-version=TZDatabaseDir -version=LibcurlPath -J$(pwd)"

    cd ..
  '';

  installPhase = ''
      cd dmd
      mkdir $out
      mkdir $out/bin
      cp ${pathToDmd} $out/bin

      mkdir -p $out/share/man/man1
      mkdir -p $out/share/man/man5
      cp -r docs/man/man1/* $out/share/man/man1/
      cp -r docs/man/man5/* $out/share/man/man5/

      cd ../druntime
      mkdir $out/include
      mkdir $out/include/dmd
      cp -r import/* $out/include/dmd

      cd ../phobos
      mkdir $out/lib
      cp generated/${osname}/release/${bits}/libphobos2.* $out/lib

      cp -r std $out/include/dmd
      cp -r etc $out/include/dmd

      wrapProgram $out/bin/dmd \
          --prefix PATH ":" "${targetPackages.stdenv.cc}/bin" \
          --set-default CC "${targetPackages.stdenv.cc}/bin/cc"

      substitute ${dmdConfFile} "$out/bin/dmd.conf" --subst-var out
  '';

  meta = with stdenv.lib; {
    description = "Official reference compiler for the D language";
    homepage = "http://dlang.org/";
    # Everything is now Boost licensed, even the backend.
    # https://github.com/dlang/dmd/pull/6680
    license = licenses.boost;
    maintainers = with maintainers; [ ThomasMader lionello ];
    platforms = [ "x86_64-linux" "i686-linux" "x86_64-darwin" ];
  };
}
