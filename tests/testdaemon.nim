#
#                  Nim's Daemonizer
#                 (c) Copyright 2018
#         Status Research & Development GmbH
#
#              Licensed under either of
#  Apache License, version 2.0, (LICENSE-APACHEv2)
#              MIT license (LICENSE-MIT)

import daemon, nativesockets, selectors, unittest, os

proc create_test_socket(): SocketHandle =
  var sock = createNativeSocket()
  setBlocking(sock, false)
  result = sock

proc checkServer(port: Port, timeout: int): bool =
  var selector = newSelector[int]()
  var serverSocket = create_test_socket()
  selector.registerHandle(serverSocket, {Event.Read}, 0)
  setSockOptInt(serverSocket, SOL_SOCKET, SO_REUSEADDR, 1)
  var aiList = getAddrInfo("0.0.0.0", port)
  if bindAddr(serverSocket, aiList.ai_addr,
              aiList.ai_addrlen.Socklen) < 0'i32:
    freeAddrInfo(aiList)
    raiseOSError(osLastError())
  discard serverSocket.listen()
  freeAddrInfo(aiList)
  var rcm = selector.select(timeout)
  serverSocket.close()
  if len(rcm) == 0:
    result = false
  else:
    result = true

proc connectServer(port: Port, timeout: int): bool =
  var selector = newSelector[int]()
  var clientSocket = create_test_socket()
  selector.registerHandle(clientSocket, {Event.Write}, 0)
  var aiList = getAddrInfo("127.0.0.1", port)
  discard connect(clientSocket, aiList.ai_addr,
                  aiList.ai_addrlen.Socklen)
  freeAddrInfo(aiList)

  var rcm = selector.select(timeout)
  clientSocket.close()
  if len(rcm) == 0:
    result = false
  else:
    result = true

when isMainModule:
  suite "Daemon testing suite":
    test "Spawning daemon process test":
      let res = daemonize()
      check res >= 0
      if res == 0:
        discard connectServer(Port(53333), 20000)
      else:
        check checkServer(Port(53333), 20000) == true
