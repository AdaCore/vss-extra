--
--  Copyright (C) 2025, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  XML writer with formatting of the output to improve human readability

private with VSS.IRIs;
with VSS.Strings;
private with VSS.XML.Attributes;
private with VSS.XML.Implementation.Error_Handlers;
private with VSS.XML.Namespace_Maps;

package VSS.XML.Writers.Pretty is

   type Attribute_Syntax is (Auto, Single_Quoted, Double_Quoted);
   --  Syntax used for attribute value of the element.

   type Pretty_XML_Writer is
     limited new VSS.XML.Writers.XML_Writer with private;

   procedure Set_Attribute_Syntax
     (Self : in out Pretty_XML_Writer'Class;
      To   : Attribute_Syntax);
   --  Set which attribute value delimiter should be used to output attibute's
   --  values.

   procedure Set_Indent
     (Self : in out Pretty_XML_Writer'Class;
      To   : VSS.Strings.Character_Count);
   --  Set indent of the nested XML tags.

private

   type Writer_Settings is limited record
      Syntax : Attribute_Syntax            := Auto;
      Indent : VSS.Strings.Character_Count := 0;
   end record;

   type Pretty_XML_Writer is
     limited new VSS.XML.Writers.XML_Writer with record
      Settings        : Writer_Settings;

      Output          : VSS.Text_Streams.Output_Text_Stream_Access;
      Error           : VSS.XML.Error_Handlers.SAX_Error_Handler_Access :=
        VSS.XML.Implementation.Error_Handlers.Default'Access;
      Namespace_Map   : VSS.XML.Namespace_Maps.XML_Namespace_Map;

      Syntax          : Attribute_Syntax;
      Indent          : VSS.Strings.Character_Count;
      Characters_Mode : Boolean;
      --  Characters data present after start tag or last element's end tag.
      CDATA_Mode      : Boolean;
      Start_Tag_Open  : Boolean;
      Offset          : VSS.Strings.Character_Count;
   end record;

   overriding procedure Start_Document
     (Self    : in out Pretty_XML_Writer;
      Success : in out Boolean);

   overriding procedure End_Document
     (Self    : in out Pretty_XML_Writer;
      Success : in out Boolean);

   overriding procedure Start_Prefix_Mapping
     (Self    : in out Pretty_XML_Writer;
      Prefix  : VSS.Strings.Virtual_String;
      URI     : VSS.IRIs.IRI;
      Success : in out Boolean);

   overriding procedure Start_Element
     (Self       : in out Pretty_XML_Writer;
      URI        : VSS.IRIs.IRI;
      Name       : VSS.Strings.Virtual_String;
      Attributes : VSS.XML.Attributes.XML_Attributes'Class;
      Success    : in out Boolean);

   overriding procedure End_Element
     (Self    : in out Pretty_XML_Writer;
      URI     : VSS.IRIs.IRI;
      Name    : VSS.Strings.Virtual_String;
      Success : in out Boolean);

   overriding procedure Characters
     (Self    : in out Pretty_XML_Writer;
      Text    : VSS.Strings.Virtual_String;
      Success : in out Boolean);

   overriding procedure Ignorable_Whitespace
     (Self    : in out Pretty_XML_Writer;
      Text    : VSS.Strings.Virtual_String;
      Success : in out Boolean) renames Characters;

   overriding procedure Processing_Instruction
     (Self    : in out Pretty_XML_Writer;
      Target  : VSS.Strings.Virtual_String;
      Data    : VSS.Strings.Virtual_String;
      Success : in out Boolean);

   overriding procedure Comment
     (Self    : in out Pretty_XML_Writer;
      Text    : VSS.Strings.Virtual_String;
      Success : in out Boolean);

   overriding procedure Start_CDATA
     (Self    : in out Pretty_XML_Writer;
      Success : in out Boolean);

   overriding procedure End_CDATA
     (Self    : in out Pretty_XML_Writer;
      Success : in out Boolean);

   overriding procedure Set_Output_Stream
     (Self   : in out Pretty_XML_Writer;
      Stream : VSS.Text_Streams.Output_Text_Stream_Access);

   overriding procedure Set_Error_Handler
     (Self : in out Pretty_XML_Writer;
      To   : VSS.XML.Error_Handlers.SAX_Error_Handler_Access);

end VSS.XML.Writers.Pretty;
