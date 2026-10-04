{
  description = "StarReplay consuming the generated StarLang wire contract";
  inputs = {
    star-router.url = "github:lost-rob0t/starRouter/20e5c9e8bf49660fd230d8e7306dd9209648f6e9";
    nixpkgs.follows = "star-router/nixpkgs";
    starintel-doc.follows = "star-router/starintel-doc";
    limdb = { url = "github:capocasa/limdb/082cba988a853d0815d0b3212848ea00af2dfc92"; flake = false; };
    lmdb = { url = "github:FedericoCeratto/nim-lmdb/88e384acc3f0d7bb627dc0a0602d1f451fd34e35"; flake = false; };
    flatty = { url = "github:treeform/flatty/07f6ba8ab96238e5bd1264cf0cea1d1746abb00c"; flake = false; };
  };
  outputs = { self, nixpkgs, star-router, starintel-doc, limdb, lmdb, flatty }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      python = pkgs.python3.withPackages (p: [p.pyzmq]);
      paths = "--noNimblePath --path:src --path:${starintel-doc}/src --path:${star-router}/src --path:${limdb} --path:${lmdb} --path:${flatty}/src --path:${star-router.inputs.cligen} --path:${star-router.inputs.zmq} --path:${star-router.inputs.ulid}/src --path:${star-router.inputs.random}/src";
      libraries = pkgs.lib.makeLibraryPath [ pkgs.pcre pkgs.zeromq pkgs.lmdb ];
      replay = pkgs.stdenv.mkDerivation {
        pname = "starReplay";
        version = "0.1.0";
        src = self;
        nativeBuildInputs = [ pkgs.nim python pkgs.makeWrapper ];
        buildPhase = ''
          nim c -d:release ${paths} --nimcache:"$TMPDIR/nimcache" --out:starReplay src/starReplay.nim
          nim c -d:release ${paths} --nimcache:"$TMPDIR/nimcache-seed" --out:seed-recording tests/seed_recording.nim
        '';
        doCheck = true;
        doInstallCheck = true;
        checkPhase = ''
          python scripts/sync-starintel-schema.py --offline
          python scripts/check-runtime-release.py ${starintel-doc} ${star-router}
          export LD_LIBRARY_PATH=${libraries}
          python tests/replay_wire.py "$PWD/starReplay" ${star-router.packages.${system}.default}/bin/starRouter "$PWD/seed-recording"
        '';
        installPhase = ''
          mkdir -p "$out/bin"
          install -m755 starReplay "$out/bin/starReplay"
          wrapProgram "$out/bin/starReplay" --prefix LD_LIBRARY_PATH : ${libraries}
        '';
        installCheckPhase = ''
          python tests/replay_wire.py "$out/bin/starReplay" ${star-router.packages.${system}.default}/bin/starRouter "$PWD/seed-recording"
        '';
      };
    in {
      packages.${system}.default = replay;
      checks.${system}.default = replay;
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.nim pkgs.nimble python ];
        LD_LIBRARY_PATH = libraries;
      };
    };
}
