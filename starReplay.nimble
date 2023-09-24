# Package

version       = "0.1.0"
author        = "nsaspy"
description   = "Replay Messages sent over starRouter or save them. "
license       = "LGPL-3.0-only"
srcDir        = "src"
bin           = @["starReplay"]


# Dependencies

requires "nim >= 1.6.14"
requires "zmq == 1.4.0"
requires "limdb == 0.3.0"
requires "starRouter >= 0.2.0"
requires "flatty"
