--
--  Copyright (C) 2025, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Ada_2022;

with VSS.Characters.Latin;
with VSS.Strings.Character_Iterators;
with VSS.XML.Attributes.Containers;

package body VSS.XML.Writers.Pretty is

   XML_Decl                 : constant VSS.Strings.Virtual_String :=
     "<?xml version=""1.0"" encoding=""UTF-8""?>";
   Start_Tag_Open           : constant VSS.Characters.Virtual_Character :=
     VSS.Characters.Latin.Less_Than_Sign;
   Start_Tag_Close          : constant VSS.Characters.Virtual_Character :=
     VSS.Characters.Latin.Greater_Than_Sign;
   Start_Tag_Self_Close     : constant VSS.Strings.Virtual_String := "/>";
   End_Tag_Open             : constant VSS.Strings.Virtual_String := "</";
   End_Tag_Close            : constant VSS.Characters.Virtual_Character :=
     VSS.Characters.Latin.Greater_Than_Sign;
   Ampersand_Reference      : constant VSS.Strings.Virtual_String := "&amp;";
   Apostrophe_Reference     : constant VSS.Strings.Virtual_String := "&apos;";
   Less_Than_Sign_Reference : constant VSS.Strings.Virtual_String := "&lt;";
   Quotation_Mark_Reference : constant VSS.Strings.Virtual_String := "&quot;";

   procedure Write
     (Self    : Pretty_XML_Writer'Class;
      Item    : VSS.Characters.Virtual_Character;
      Success : in out Boolean);
   --  Write given character to output stream.

   procedure Write
     (Self    : Pretty_XML_Writer'Class;
      Item    : VSS.Strings.Virtual_String;
      Success : in out Boolean);
   --  Write given text to output stream.

   procedure Write_New_Line
     (Self    : Pretty_XML_Writer'Class;
      Success : in out Boolean);
   --  Write LINE FEED (16#0A#) character and `Self.Offset` SPACE characters.

   type Qname_Kind is (Tag, Attribute);

   procedure Write_Qname
     (Self    : Pretty_XML_Writer'Class;
      Kind    : Qname_Kind;
      URI     : VSS.IRIs.IRI;
      Name    : VSS.Strings.Virtual_String;
      Success : in out Boolean);
   --  Resolve namespace and write `Qname`

   procedure Write_Escaped_Text
     (Self    : in out Pretty_XML_Writer'Class;
      Item    : VSS.Strings.Virtual_String;
      Success : in out Boolean);
   --  Escape and write given text to output stream.

   procedure Write_Attribute
     (Self    : in out Pretty_XML_Writer'Class;
      URI     : VSS.IRIs.IRI;
      Name    : VSS.Strings.Virtual_String;
      Value   : VSS.Strings.Virtual_String;
      Success : in out Boolean);

   function Best_Attribute_Syntax
     (Self  : Pretty_XML_Writer'Class;
      Value : VSS.Strings.Virtual_String) return Attribute_Syntax;
   --  Computes most appropriate syntax for the given attribute's value.

   ---------------------------
   -- Best_Attribute_Syntax --
   ---------------------------

   function Best_Attribute_Syntax
     (Self  : Pretty_XML_Writer'Class;
      Value : VSS.Strings.Virtual_String) return Attribute_Syntax
   is
      Single : Natural := 0;
      Double : Natural := 0;

   begin
      if Self.Syntax /= Auto then
         return Self.Syntax;
      end if;

      if Value.Is_Empty then
         return Single_Quoted;
      end if;

      declare
         Iterator : VSS.Strings.Character_Iterators.Character_Iterator :=
           Value.Before_First_Character;

      begin
         while Iterator.Forward loop
            case Iterator.Element is
               when VSS.Characters.Latin.Quotation_Mark =>
                  Double := @ + 1;

               when VSS.Characters.Latin.Apostrophe =>
                  Single := @ + 1;

               when others =>
                  null;
            end case;
         end loop;

         if Single <= Double then
            return Single_Quoted;

         else
            return Double_Quoted;
         end if;
      end;
   end Best_Attribute_Syntax;

   ----------------
   -- Characters --
   ----------------

   overriding procedure Characters
     (Self    : in out Pretty_XML_Writer;
      Text    : VSS.Strings.Virtual_String;
      Success : in out Boolean) is
   begin
      if not Success then
         return;
      end if;

      if Self.Start_Tag_Open then
         Self.Write (Start_Tag_Close, Success);
         Self.Start_Tag_Open := False;
      end if;

      if Self.CDATA_Mode then
         raise Program_Error;
   --        --  In CDATA mode text is written to output immidiately: CDATA is
   --        --  not allowed in HTML, thus there is no enough information to do
   --        --  any transformations.
   --
   --        Self.Write_Escaped_Text (Text, Success);

      else
         Self.Write_Escaped_Text (Text, Success);
         Self.Characters_Mode := True;
      end if;
   end Characters;

   -------------
   -- Comment --
   -------------

   overriding procedure Comment
     (Self    : in out Pretty_XML_Writer;
      Text    : VSS.Strings.Virtual_String;
      Success : in out Boolean) is
   begin
      raise Program_Error;
   end Comment;

   ---------------
   -- End_CDATA --
   ---------------

   overriding procedure End_CDATA
     (Self    : in out Pretty_XML_Writer;
      Success : in out Boolean) is
   begin
      raise Program_Error;
   end End_CDATA;

   ------------------
   -- End_Document --
   ------------------

   overriding procedure End_Document
     (Self    : in out Pretty_XML_Writer;
      Success : in out Boolean) is
   begin
      raise Program_Error;
   end End_Document;

   -----------------
   -- End_Element --
   -----------------

   overriding procedure End_Element
     (Self    : in out Pretty_XML_Writer;
      URI     : VSS.IRIs.IRI;
      Name    : VSS.Strings.Virtual_String;
      Success : in out Boolean)
   is
      use type VSS.Strings.Character_Count;

   begin
      Self.Offset := @ - Self.Indent;

      if Self.Start_Tag_Open then
         Self.Write (Start_Tag_Self_Close, Success);
         Self.Start_Tag_Open := False;

      else
         if not Self.Characters_Mode then
            Self.Write_New_Line (Success);
         end if;

         Self.Write (End_Tag_Open, Success);
         Self.Write_Qname (Tag, URI, Name, Success);
         Self.Write (End_Tag_Close, Success);
      end if;

      Self.Namespace_Map.End_Element;

      Self.Characters_Mode := False;
   end End_Element;

   ----------------------------
   -- Processing_Instruction --
   ----------------------------

   overriding procedure Processing_Instruction
     (Self    : in out Pretty_XML_Writer;
      Target  : VSS.Strings.Virtual_String;
      Data    : VSS.Strings.Virtual_String;
      Success : in out Boolean) is
   begin
      raise Program_Error;
   end Processing_Instruction;

   --------------------------
   -- Set_Attribute_Syntax --
   --------------------------

   procedure Set_Attribute_Syntax
     (Self : in out Pretty_XML_Writer'Class;
      To   : Attribute_Syntax) is
   begin
      Self.Settings.Syntax := To;
   end Set_Attribute_Syntax;

   -----------------------
   -- Set_Error_Handler --
   -----------------------

   overriding procedure Set_Error_Handler
     (Self : in out Pretty_XML_Writer;
      To   : VSS.XML.Error_Handlers.SAX_Error_Handler_Access) is
   begin
      Self.Error := To;
   end Set_Error_Handler;

   ----------------
   -- Set_Indent --
   ----------------

   procedure Set_Indent
     (Self : in out Pretty_XML_Writer'Class;
      To   : VSS.Strings.Character_Count) is
   begin
      Self.Settings.Indent := To;
   end Set_Indent;

   -----------------------
   -- Set_Output_Stream --
   -----------------------

   overriding procedure Set_Output_Stream
     (Self   : in out Pretty_XML_Writer;
      Stream : VSS.Text_Streams.Output_Text_Stream_Access) is
   begin
      Self.Output := Stream;
   end Set_Output_Stream;

   -----------------
   -- Start_CDATA --
   -----------------

   overriding procedure Start_CDATA
     (Self    : in out Pretty_XML_Writer;
      Success : in out Boolean) is
   begin
      raise Program_Error;
   end Start_CDATA;

   --------------------
   -- Start_Document --
   --------------------

   overriding procedure Start_Document
     (Self    : in out Pretty_XML_Writer;
      Success : in out Boolean) is
   begin
      Self.Syntax          := Self.Settings.Syntax;
      Self.Indent          := Self.Settings.Indent;
      Self.Offset          := 0;

      Self.Characters_Mode := False;
      Self.CDATA_Mode      := False;
      Self.Start_Tag_Open  := False;

      Self.Write (XML_Decl, Success);
   end Start_Document;

   -------------------
   -- Start_Element --
   -------------------

   overriding procedure Start_Element
     (Self       : in out Pretty_XML_Writer;
      URI        : VSS.IRIs.IRI;
      Name       : VSS.Strings.Virtual_String;
      Attributes : VSS.XML.Attributes.XML_Attributes'Class;
      Success    : in out Boolean)
   is
      use type VSS.Strings.Character_Count;

      NS_Attributes : VSS.XML.Attributes.Containers.Attributes;

   begin
      if not Success then
         return;
      end if;

      if Self.Start_Tag_Open then
         Self.Write (Start_Tag_Close, Success);
         Self.Start_Tag_Open := False;
      end if;

      if not Self.Characters_Mode then
         Self.Write_New_Line (Success);
      end if;

      Self.Offset := @ + Self.Indent;

      Self.Namespace_Map.Start_Element (NS_Attributes);

      Self.Write (Start_Tag_Open, Success);
      Self.Write_Qname (Tag, URI, Name, Success);

      for J in 1 .. NS_Attributes.Get_Length loop
         Self.Write_Attribute
           (URI     => NS_Attributes.Get_URI (J),
            Name    => NS_Attributes.Get_Name (J),
            Value   => NS_Attributes.Get_Value (J),
            Success => Success);
      end loop;

      for J in 1 .. Attributes.Get_Length loop
         Self.Write_Attribute
           (URI     => Attributes.Get_URI (J),
            Name    => Attributes.Get_Name (J),
            Value   => Attributes.Get_Value (J),
            Success => Success);
      end loop;

      Self.Characters_Mode := False;
      Self.Start_Tag_Open  := True;
   end Start_Element;

   --------------------------
   -- Start_Prefix_Mapping --
   --------------------------

   overriding procedure Start_Prefix_Mapping
     (Self    : in out Pretty_XML_Writer;
      Prefix  : VSS.Strings.Virtual_String;
      URI     : VSS.IRIs.IRI;
      Success : in out Boolean) is
   begin
      if not Success then
         return;
      end if;

      Self.Namespace_Map.Start_Prefix_Mapping (Prefix, URI);
   end Start_Prefix_Mapping;

   -----------
   -- Write --
   -----------

   procedure Write
     (Self    : Pretty_XML_Writer'Class;
      Item    : VSS.Characters.Virtual_Character;
      Success : in out Boolean)
   is
      use type VSS.Text_Streams.Output_Text_Stream_Access;

   begin
      if Self.Output /= null then
         Self.Output.Put (Item, Success);

      else
         --  Success := False;

         raise Program_Error;
      end if;
   end Write;

   -----------
   -- Write --
   -----------

   procedure Write
     (Self    : Pretty_XML_Writer'Class;
      Item    : VSS.Strings.Virtual_String;
      Success : in out Boolean)
   is
      use type VSS.Text_Streams.Output_Text_Stream_Access;

   begin
      if Self.Output /= null then
         Self.Output.Put (Item, Success);

      else
         --  Success := False;

         raise Program_Error;
      end if;
   end Write;

   ---------------------
   -- Write_Attribute --
   ---------------------

   procedure Write_Attribute
     (Self    : in out Pretty_XML_Writer'Class;
      URI     : VSS.IRIs.IRI;
      Name    : VSS.Strings.Virtual_String;
      Value   : VSS.Strings.Virtual_String;
      Success : in out Boolean)
   is
      use type VSS.Text_Streams.Output_Text_Stream_Access;

      procedure Write_Single_Quoted_Value;

      procedure Write_Double_Quoted_Value;

      -------------------------------
      -- Write_Double_Quoted_Value --
      -------------------------------

      procedure Write_Double_Quoted_Value is
         Iterator : VSS.Strings.Character_Iterators.Character_Iterator :=
           Value.Before_First_Character;

      begin
         while Iterator.Forward loop
            declare
               C : constant VSS.Characters.Virtual_Character :=
                 Iterator.Element;

            begin
               case C is
                  when VSS.Characters.Latin.Quotation_Mark =>
                     Self.Write (Quotation_Mark_Reference, Success);

                  when VSS.Characters.Latin.Ampersand =>
                     Self.Write (Ampersand_Reference, Success);

                  when VSS.Characters.Latin.Less_Than_Sign =>
                     Self.Write (Less_Than_Sign_Reference, Success);

                  when others =>
                     Self.Output.Put (C, Success);
               end case;
            end;
         end loop;
      end Write_Double_Quoted_Value;

      -------------------------------
      -- Write_Single_Quoted_Value --
      -------------------------------

      procedure Write_Single_Quoted_Value is
         Iterator : VSS.Strings.Character_Iterators.Character_Iterator :=
           Value.Before_First_Character;

      begin
         while Iterator.Forward loop
            declare
               C : constant VSS.Characters.Virtual_Character :=
                 Iterator.Element;

            begin
               case C is
                  when VSS.Characters.Latin.Ampersand =>
                     Self.Write (Ampersand_Reference, Success);

                  when VSS.Characters.Latin.Apostrophe =>
                     Self.Write (Apostrophe_Reference, Success);

                  when VSS.Characters.Latin.Less_Than_Sign =>
                     Self.Write (Less_Than_Sign_Reference, Success);

                  when others =>
                     Self.Output.Put (C, Success);
               end case;
            end;
         end loop;
      end Write_Single_Quoted_Value;

      Syntax : constant Attribute_Syntax := Self.Best_Attribute_Syntax (Value);

   begin
      if Self.Output /= null then
         Self.Write (VSS.Characters.Latin.Space, Success);
         Self.Write_Qname (Attribute, URI, Name, Success);
         Self.Write (VSS.Characters.Latin.Equals_Sign, Success);

         case Syntax is
            when Auto =>
               raise Program_Error;

            when Single_Quoted =>
               Self.Write (VSS.Characters.Latin.Apostrophe, Success);
               Write_Single_Quoted_Value;
               Self.Write (VSS.Characters.Latin.Apostrophe, Success);

            when Double_Quoted =>
               Self.Write (VSS.Characters.Latin.Quotation_Mark, Success);
               Write_Double_Quoted_Value;
               Self.Write (VSS.Characters.Latin.Quotation_Mark, Success);
         end case;

      else
         --  Success := False;

         raise Program_Error;
      end if;
   end Write_Attribute;

   ------------------------
   -- Write_Escaped_Text --
   ------------------------

   procedure Write_Escaped_Text
     (Self    : in out Pretty_XML_Writer'Class;
      Item    : VSS.Strings.Virtual_String;
      Success : in out Boolean)
   is
      use type VSS.Characters.Virtual_Character;
      use type VSS.Text_Streams.Output_Text_Stream_Access;

   begin
      if Self.Output /= null then
         declare
            Iterator : VSS.Strings.Character_Iterators.Character_Iterator :=
              Item.Before_First_Character;

         begin
            while Iterator.Forward loop
               declare
                  C : constant VSS.Characters.Virtual_Character :=
                    Iterator.Element;

               begin
                  if Self.CDATA_Mode then
                     if C = VSS.Characters.Latin.Greater_Than_Sign then
                        --  XXX End of CDATA!!!
                        raise Program_Error;
                     end if;

                     Self.Output.Put (C, Success);

                  elsif C = VSS.Characters.Latin.Ampersand then
                     Self.Write (Ampersand_Reference, Success);

                  elsif C = VSS.Characters.Latin.Less_Than_Sign then
                     Self.Write (Less_Than_Sign_Reference, Success);

                  --  elsif C = VSS.Characters.Latin.Greater_Than_Sign then
                  --     --  XXX End of CDATA!!!
                  --     raise Program_Error;

                  else
                     Self.Output.Put (C, Success);
                  end if;
               end;
            end loop;
         end;

      else
         --  Success := False;

         raise Program_Error;
      end if;
   end Write_Escaped_Text;

   --------------------
   -- Write_New_Line --
   --------------------

   procedure Write_New_Line
     (Self    : Pretty_XML_Writer'Class;
      Success : in out Boolean) is
   begin
      Self.Write (VSS.Characters.Latin.Line_Feed, Success);

      for J in 1 .. Self.Offset loop
         Self.Write (VSS.Characters.Latin.Space, Success);
      end loop;
   end Write_New_Line;

   -----------------
   -- Write_Qname --
   -----------------

   procedure Write_Qname
     (Self    : Pretty_XML_Writer'Class;
      Kind    : Qname_Kind;
      URI     : VSS.IRIs.IRI;
      Name    : VSS.Strings.Virtual_String;
      Success : in out Boolean)
   is
      use type VSS.Strings.Virtual_String;

      Prefix : constant VSS.Strings.Virtual_String :=
        (if not URI.Is_Empty
           then Self.Namespace_Map.Prefix (URI)
           elsif Kind = Attribute
             then VSS.Strings.Empty_Virtual_String
             else raise Program_Error);

   begin
      if not Prefix.Is_Empty then
         Self.Write (Prefix, Success);

         --  "xmlns" is reserved by XML Namespaces. `Name` can be empty to map
         --  namespace URI to default prefix.

         if Prefix /= "xmlns" or not Name.Is_Empty then
            Self.Write (VSS.Characters.Latin.Colon, Success);
         end if;
      end if;

      Self.Write (Name, Success);
   end Write_Qname;

end VSS.XML.Writers.Pretty;
