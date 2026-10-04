# Package

version       = "0.1.0"
author        = "nsaspy"
description   = "Replay Messages sent over starRouter or save them. "
license       = "LGPL-3.0-only"
srcDir        = "src"
bin           = @["starReplay"]


# Dependencies

requires "nim >= 2.0.0"
requires "https://github.com/nim-lang/nim-zmq.git#a56af54f599337a8f5d4934fcff7554c74f77854"
requires "https://github.com/capocasa/limdb.git#082cba988a853d0815d0b3212848ea00af2dfc92"
requires "https://github.com/lost-rob0t/starRouter.git#20e5c9e8bf49660fd230d8e7306dd9209648f6e9"
requires "https://github.com/lost-rob0t/starintel-doc.nim.git#827f2c072e9893561a1925c47f898458bafd6759"
requires "https://github.com/treeform/flatty.git#07f6ba8ab96238e5bd1264cf0cea1d1746abb00c"
requires "https://github.com/FedericoCeratto/nim-lmdb.git#88e384acc3f0d7bb627dc0a0602d1f451fd34e35"
requires "cligen"
