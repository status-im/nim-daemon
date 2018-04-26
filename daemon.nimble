packageName   = "daemon"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Cross-platform process daemonization"
license       = "Apache License 2.0 or MIT"
skipDirs      = @["tests", "Nim", "nim"]

### Dependencies

requires "nim >= 0.18.0"

task test, "Run all tests":
  exec "nim c -r tests/testdaemon"
  exec "nim c -r -d:release tests/testdaemon"
