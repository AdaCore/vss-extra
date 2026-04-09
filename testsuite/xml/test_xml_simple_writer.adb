--
--  Copyright (C) 2026, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Ada.Command_Line;

with VSS.XML.Writers.Simple;
with VSS.XML.XmlAda_Readers;

with Input_Sources.File;

with Stdout_Text_Streams;

procedure Test_XML_Simple_Writer is
   Input  : Input_Sources.File.File_Input;
   Reader : VSS.XML.XmlAda_Readers.XmlAda_Reader;
   Writer : aliased VSS.XML.Writers.Simple.Simple_XML_Writer;
   Output : aliased Stdout_Text_Streams.Output_Text_Stream;

begin
   Input_Sources.File.Open
    (Ada.Command_Line.Argument (1), Input);

   Writer.Set_Output_Stream (Output'Unchecked_Access);
   Reader.Set_Content_Handler (Writer'Unchecked_Access);
   Reader.Set_Lexical_Handler (Writer'Unchecked_Access);

   Reader.Parse (Input);
   Input.Close;
end Test_XML_Simple_Writer;
