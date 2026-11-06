--
--  Copyright (C) 2022-2026, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Low level binding to Windows API (KERNEL32.DLL).

package VSS.Implementation.Windows.Kernel32 is

   pragma Linker_Options ("-lkernel32");

   type STARTUPINFO is record
      cb              : DWORD;
      lpReserved      : LPWSTR;
      lpDesktop       : LPWSTR;
      lpTitle         : LPWSTR;
      dwX             : DWORD;
      dwY             : DWORD;
      dwXSize         : DWORD;
      dwYSize         : DWORD;
      dwXCountChars   : DWORD;
      dwYCountChars   : DWORD;
      dwFillAttribute : DWORD;
      dwFlags         : DWORD;
      wShowWindow     : WORD;
      cbReserved2     : WORD;
      lpReserved2     : LPBYTE;
      hStdInput       : HANDLE;
      hStdOutput      : HANDLE;
      hStdError       : HANDLE;
   end record
     with Convention => C;

   type LPSTARTUPINFO is access all STARTUPINFO with Convention => C;

   STARTF_USESTDHANDLES : constant DWORD := 16#0000_0100#;

   STD_INPUT_HANDLE  : constant DWORD := 16#FFFFFFF6#;
   STD_OUTPUT_HANDLE : constant DWORD := 16#FFFFFFF5#;
   STD_ERROR_HANDLE  : constant DWORD := 16#FFFFFFF4#;

   FILE_TYPE_UNKNOWN : constant DWORD := 0;
   FILE_TYPE_DISK    : constant DWORD := 1;
   FILE_TYPE_CHAR    : constant DWORD := 2;
   FILE_TYPE_PIPE    : constant DWORD := 3;
   FILE_TYPE_REMOTE  : constant DWORD := 16#8000#;

   function CloseHandle (hObject : HANDLE) return BOOL
     with Import, Convention => Stdcall, External_Name => "CloseHandle";

   function GetCommandLine return LPWSTR
     with Import, Convention => Stdcall, External_Name => "GetCommandLineW";

   function GetConsoleWindow return HWND
     with Import, Convention => Stdcall, External_Name => "GetConsoleWindow";

   function GetCurrentProcess return HANDLE
     with Import, Convention => Stdcall, External_Name => "GetCurrentProcess";

   function GetEnvironmentVariable
     (lpName   : LPCWSTR;
      lpBuffer : LPWSTR;
      nSize    : DWORD) return DWORD
     with Import,
          Convention => Stdcall,
          External_Name  => "GetEnvironmentVariableW";

   function GetFileType
     (hFile : HANDLE) return DWORD
     with Import, Convention => Stdcall, External_Name => "GetFileType";

   function GetLastError return DWORD
     with Import, Convention => Stdcall, External_Name => "GetLastError";

   procedure GetStartupInfo
     (lpStartupInfo : Kernel32.LPSTARTUPINFO)
     with Import, Convention => StdCall, External_Name => "GetStartupInfoW";

   function GetStdHandle
     (nStdHandle : DWORD) return HANDLE
     with Import, Convention => Stdcall, External_Name => "GetStdHandle";

   function GetTempPath
     (nBufferLength : DWORD;
      lpBuffer      : LPWSTR) return DWORD
      with Import, Convention => Stdcall, External_Name => "GetTempPathW";

   function GetLongPathName
     (lpszShortPath : LPCWSTR;
      lpszLongPath  : LPWSTR;
      cchBuffer     : DWORD) return DWORD
      with Import, Convention => Stdcall, External_Name => "GetLongPathNameW";

   function GetModuleFileName
     (hModule    : HANDLE;
      lpFilename : LPWSTR;
      nSize      : DWORD) return DWORD
     with Import, Convention => StdCall, External_Name => "GetModuleFileNameW";

   procedure LocalFree (hMem : LPWSTR_Pointer)
     with Import, Convention => StdCall, External_Name => "LocalFree";

end VSS.Implementation.Windows.Kernel32;
