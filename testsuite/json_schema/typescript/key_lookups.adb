--
--  Copyright (C) 2026, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

package body Key_Lookups is

   ---------------
   -- Get_Index --
   ---------------

   function Get_Index (Text : VSS.Strings.Virtual_String) return Natural is
      use type VSS.Strings.Virtual_String;
   begin
      for Index in 1 .. Variants.Length loop
         if Variants (Index) = Text then
            return Index;
         end if;
      end loop;

      return 0;
   end Get_Index;

end Key_Lookups;
