#
#                   Nim's Daemonize
#                 (c) Copyright 2018
#         Status Research & Development GmbH
#
#              Licensed under either of
#  Apache License, version 2.0, (LICENSE-APACHEv2)
#              MIT license (LICENSE-MIT)

## This module implements cross-platform process daemonization.
## Windows, Linux, MacOS, FreeBSD, OpenBSD, NetBSD, DragonflyBSD are supported.

when defined(nimdoc):
  proc daemonize*(pidfile: string = ""): int =
    ## Daemonize process, and stored process identifier in `pidfile`.
    ## 
    ## Returns `0` if process is daemonized child, `>0`, if
    ## process is parent, and `<0` if there error happens.

when defined(windows):
  import winlean, os, strutils
  const
    DaemonEnvVariable = "NIM_DAEMONIZE"
    CREATE_NEW_PROCESS_GROUP = 0x00000200'i32
    DETACHED_PROCESS = 0x00000008'i32
  
  proc getEnvironmentVariableW(lpName, lpValue: WideCString,
                               nSize: int32): int32 {.
    stdcall, dynlib: "kernel32", importc: "GetEnvironmentVariableW".}

  proc daemonize*(pidfile: string = ""): int =
    var
      si: STARTUPINFO
      pi: PROCESS_INFORMATION
      sa: SECURITY_ATTRIBUTES
      evar: array[32, byte]
      res: int32
    var cmdLineW = getCommandLineW()
    res = getEnvironmentVariableW(newWideCString(DaemonEnvVariable),
                                  cast[WideCString](addr evar[0]), 16)
    if res > 0:
      result = 0
    else:
      sa.nLength = int32(sizeof(SECURITY_ATTRIBUTES))
      sa.bInheritHandle = 1'i32
      var path = newWideCString("NUL")
      si.dwFlags = STARTF_USESTDHANDLES
      var handle = createFileW(path, GENERIC_WRITE or GENERIC_READ,
                               FILE_SHARE_READ or FILE_SHARE_WRITE, addr sa,
                               OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, Handle(0))

      if handle == INVALID_HANDLE_VALUE:
        return -1

      si.hStdInput = handle
      si.hStdOutput = handle
      si.hStdError = handle

      if setEnvironmentVariableW(newWideCString(DaemonEnvVariable),
                                 newWideCString("true")) == 0:
        return -1
      var flags = CREATE_NEW_PROCESS_GROUP or DETACHED_PROCESS or
                  CREATE_UNICODE_ENVIRONMENT
      res = winlean.createProcessW(nil, cmdLineW, nil, nil, 1, flags, nil,
                                   nil, si, pi)
      if res == 0:
        return -1
      else:
        if len(pidfile) > 0:
          writeFile(pidfile, $pi.dwProcessId)
        result = pi.dwProcessId

elif defined(posix):
  import posix, os

  proc daemonize*(pidfile: string =  ""): int =
    var
      pid: Pid
      sinp, sout, serr: File
    pid = posix.fork()
    if pid < 0 or pid > 0:
      return int(pid)
    else:
      if posix.setsid() < 0:
        quit(QuitFailure)
      posix.signal(SIGCHLD, SIG_IGN)
      pid = posix.fork()
      if pid < 0:
        quit(QuitFailure)
      if pid > 0:
        quit(QuitSuccess)
      discard posix.umask(0)
      if not sinp.open("/dev/null", fmRead):
        quit(QuitFailure)
      if not sout.open("/dev/null", fmAppend):
        quit(QuitFailure)
      if not serr.open("/dev/null", fmAppend):
        quit(QuitFailure)
      if posix.dup2(getFileHandle(sinp), getFileHandle(stdin)) < 0:
        quit(QuitFailure)
      if posix.dup2(getFileHandle(sout), getFileHandle(stdout)) < 0:
        quit(QuitFailure)
      if posix.dup2(getFileHandle(serr), getFileHandle(stderr)) < 0:
        quit(QuitFailure)
      if len(pidfile) > 0:
        writeFile(pidfile, $pid)
      result = 0
