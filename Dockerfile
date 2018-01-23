FROM nixos/nix:1.11

RUN apk update && apk --no-cache add curl bash openssl make

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs &&\
    nix-channel --add https://nix.dapphub.com/pkgs/dapphub &&\
    nix-channel --update
RUN nix-env -iA dapphub.dapp dapphub.seth dapphub.hevm dapphub.evmdis

ENTRYPOINT [ "/bin/bash" ]
