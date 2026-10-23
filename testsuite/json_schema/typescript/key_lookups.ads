--
--  Copyright (C) 2026, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  A replacement for Minimal_Perfect_Hash to check --hash-package option

with VSS.String_Vectors;
with VSS.Strings;

generic
   Variants : VSS.String_Vectors.Virtual_String_Vector;
package Key_Lookups is

   function Get_Index (Text : VSS.Strings.Virtual_String) return Natural;
   --  Return index of Text in Variants or zero

end Key_Lookups;
