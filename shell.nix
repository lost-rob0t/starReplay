{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    lmdb
    nim
    zeromq
  ];
}
