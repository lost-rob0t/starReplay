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
requires "limdb == 0.3.0"
requires "https://github.com/lost-rob0t/starRouter.git#cda4722013a94df46c309a7c14c177caf79bfae5"
requires "flatty"
