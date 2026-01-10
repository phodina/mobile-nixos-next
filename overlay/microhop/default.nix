{ lib, fetchFromGitHub, rustPlatform, pkg-config, llvmPackages, util-linux, glibc, gcc, stdenv }:
{
  # Cross-compiled microhop (for ARM64)
  microhop = rustPlatform.buildRustPackage rec {
    pname = "microhop";
    version = "unstable-2024-12-18";
    src = fetchFromGitHub {
      owner = "tinythings";
      repo = "microhop";
      rev = "6af7b536abbbeaddf65a3df03bb0ea564de0d75c";
      hash = "sha256-AzH1AuYVf/zTKAVXgKBx2zoSYbkrG/4N3B5kX/YLdaw=";
    };
    cargoHash = "sha256-kkqgy3vfbnGzVLwMATeBwcZZCxcY3ivB4OlXdrCMXpU=";
    
    nativeBuildInputs = [ pkg-config util-linux.dev llvmPackages.clang ];
    buildInputs = [ glibc util-linux ];
    
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-I${glibc.dev}/include -I${llvmPackages.clang.cc}/include -I${util-linux.dev}/include";
    CFLAGS = "-I${glibc.dev}/include -I${llvmPackages.clang.cc}/include -I${util-linux.dev}/include";
    CPPFLAGS = "-I${glibc.dev}/include -I${llvmPackages.clang.cc}/include -I${util-linux.dev}/include";
    
    cargoBuildFlags = [ "--bin" "microhop" "--target" "aarch64-unknown-linux-gnu" ];
    
    installPhase = ''
      mkdir -p $out/bin
      cp target/aarch64-unknown-linux-gnu/release/microhop $out/bin/
    '';
    
    meta = with lib; {
      description = "Tiny initramfs generator written in Rust (ARM64 /init)";
      homepage = "https://github.com/tinythings/microhop";
      license = licenses.asl20;
      platforms = [ "aarch64-linux" ];
    };
  };

  # Native microgen (host tool)
  microgen = rustPlatform.buildRustPackage rec {
    pname = "microgen";
    version = "unstable-2024-12-18";
    src = fetchFromGitHub {
      owner = "tinythings";
      repo = "microhop";
      rev = "6af7b536abbbeaddf65a3df03bb0ea564de0d75c";
      hash = "sha256-AzH1AuYVf/zTKAVXgKBx2zoSYbkrG/4N3B5kX/YLdaw=";
    };
    cargoHash = "sha256-kkqgy3vfbnGzVLwMATeBwcZZCxcY3ivB4OlXdrCMXpU=";
    
    nativeBuildInputs = [ pkg-config llvmPackages.clang ];
    buildInputs = [ util-linux ];
    
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-I${util-linux.dev}/include";
    
    buildPhase = ''
      cargo build --package microgen --release --offline
    '';
    
    checkPhase = ''
      cargo test --package microgen --release --offline
    '';
    
    installPhase = ''
      mkdir -p $out/bin
      cp target/release/microgen $out/bin/
    '';
    
    meta = with lib; {
      description = "Microhop initramfs generator utility (host tool)";
      homepage = "https://github.com/tinythings/microhop";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  };
}
