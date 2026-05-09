{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "jpcal";
  version = "unstable-2026-03-20";

  src = fetchFromGitHub {
    owner = "y-yagi";
    repo = "jpcal";
    rev = "8e90dd1d78d79eb27905727df22ffbcfeaef6b92";
    hash = "sha256-GfLclkBGcj7BuPR5SeYyrWNreEFazF+ORJRERhBpyP0=";
  };

  vendorHash = "sha256-fJ9EYIziaFKdKjJXXAS1HFRPLYBAoLpFRdww4JS/hX0=";

  ldflags = [ "-s" "-w" ];

  meta = with lib; {
    description = "Command-line Japanese calendar with national holidays";
    homepage = "https://github.com/y-yagi/jpcal";
    license = licenses.mit;
    mainProgram = "jpcal";
    platforms = platforms.unix;
  };
}
