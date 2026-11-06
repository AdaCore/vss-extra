--
--  Copyright (C) 2022-2026, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Interfaces.C;

with VSS.Implementation.Windows.Kernel32;
with VSS.Implementation.Windows.String_Utilities;
with VSS.Implementation.Windows.User32;

separate (VSS.Command_Line)
package body Platform is

   function Use_Message_Box return Boolean;
   --  Return True then message box should be used instead of standard error
   --  stream to report errors.

   procedure Display_Message_Box
     (Message  : VSS.Strings.Virtual_String;
      Is_Error : Boolean);

   -------------------------
   -- Display_Message_Box --
   -------------------------

   procedure Display_Message_Box
     (Message  : VSS.Strings.Virtual_String;
      Is_Error : Boolean)
   is
      use type VSS.Implementation.Windows.UINT;

      Title  : VSS.Implementation.Windows.String_Utilities.char16_array_access;
      Text   : VSS.Implementation.Windows.String_Utilities.char16_array_access;
      Result : Interfaces.C.int with Unreferenced;

   begin
      Text :=
        VSS.Implementation.Windows.String_Utilities.To_New_Native_String
          (Message);
      Title :=
        VSS.Implementation.Windows.String_Utilities.To_New_Native_String
          (VSS.Application.Application_File);
      Result :=
        VSS.Implementation.Windows.User32.MessageBox
          (0,
           Text (Text'First)'Access,
           Title (Title'First)'Access,
           VSS.Implementation.Windows.User32.MB_OK
             or VSS.Implementation.Windows.User32.MB_TOPMOST
             or VSS.Implementation.Windows.User32.MB_SETFOREGROUND
             or (if Is_Error
                   then VSS.Implementation.Windows.User32.MB_ICONERROR
                   else VSS.Implementation.Windows.User32.MB_ICONINFORMATION));
      VSS.Implementation.Windows.String_Utilities.Free (Text);
      VSS.Implementation.Windows.String_Utilities.Free (Title);
   end Display_Message_Box;

   --------------------
   -- Report_Message --
   --------------------

   procedure Report_Message
     (Message  : VSS.Strings.Virtual_String;
      Is_Error : Boolean) is
   begin
      if Use_Message_Box then
         Display_Message_Box (Message, Is_Error);

      elsif Is_Error then
         Put_Line_Error (Message);

      else
         Put_Line_Output (Message);
      end if;
   end Report_Message;

   --------------------
   -- Report_Message --
   --------------------

   procedure Report_Message
     (Message  : VSS.String_Vectors.Virtual_String_Vector;
      Is_Error : Boolean) is
   begin
      if Use_Message_Box then
         Display_Message_Box (Message.Join_Lines (VSS.Strings.CRLF), Is_Error);

      else
         for Line of Message loop
            if Is_Error then
               Put_Line_Error (Line);

            else
               Put_Line_Output (Line);
            end if;
         end loop;
      end if;
   end Report_Message;

   ---------------------
   -- Use_Message_Box --
   ---------------------

   function Use_Message_Box return Boolean is
      use type VSS.Implementation.Windows.DWORD;
      use type VSS.Implementation.Windows.HANDLE;
      use type VSS.Implementation.Windows.HWND;

      Info       : aliased VSS.Implementation.Windows.Kernel32.STARTUPINFO;
      Out_Handle : VSS.Implementation.Windows.HANDLE;
      Err_Handle : VSS.Implementation.Windows.HANDLE;
      Out_Valid  : Boolean;
      Err_Valid  : Boolean;

   begin
      --  Initialize STARTUPINFO record

      Info.cb :=
        VSS.Implementation.Windows.Kernel32
          .STARTUPINFO'Max_Size_In_Storage_Elements;

      --  1. Obtain startup information and check for STARTF_USESTDHANDLES

      VSS.Implementation.Windows.Kernel32.GetStartupInfo
        (Info'Unchecked_Access);

      if (Info.dwFlags
          and VSS.Implementation.Windows.Kernel32.STARTF_USESTDHANDLES)
        /= 0
      then
         --  Standard IO streams was specified for the application.

         return False;
      end if;

      --  2. Check for associated console window

      if VSS.Implementation.Windows.Kernel32.GetConsoleWindow /= 0 then
         --  Application has associated console window.

         return False;
      end if;

      --  3. Handles of both standard output and standard error is not
      --  valid...

      Out_Handle :=
        VSS.Implementation.Windows.Kernel32.GetStdHandle
          (VSS.Implementation.Windows.Kernel32.STD_OUTPUT_HANDLE);
      Err_Handle :=
        VSS.Implementation.Windows.Kernel32.GetStdHandle
          (VSS.Implementation.Windows.Kernel32.STD_ERROR_HANDLE);

      Out_Valid :=
        Out_Handle /= VSS.Implementation.Windows.INVALID_HANDLE_VALUE
        and Out_Handle /= VSS.Implementation.Windows.NULL_HANDLE_VALUE;
      Err_Valid :=
        Err_Handle /= VSS.Implementation.Windows.INVALID_HANDLE_VALUE
        and Err_Handle /= VSS.Implementation.Windows.NULL_HANDLE_VALUE;

      --  4. ... or not a character device, pipe, or disk.

      if Out_Valid
        and then
          (VSS.Implementation.Windows.Kernel32.GetFileType (Out_Handle)
           in VSS.Implementation.Windows.Kernel32.FILE_TYPE_CHAR
            | VSS.Implementation.Windows.Kernel32.FILE_TYPE_PIPE
            | VSS.Implementation.Windows.Kernel32.FILE_TYPE_DISK)
      then
         return False;
      end if;

      if Err_Valid
        and then
          (VSS.Implementation.Windows.Kernel32.GetFileType (Err_Handle)
           in VSS.Implementation.Windows.Kernel32.FILE_TYPE_CHAR
            | VSS.Implementation.Windows.Kernel32.FILE_TYPE_PIPE
            | VSS.Implementation.Windows.Kernel32.FILE_TYPE_DISK)
      then
         return False;
      end if;

      return True;
   end Use_Message_Box;

end Platform;
