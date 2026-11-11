--
--  Copyright (C) 2026, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Ada.Streams;
with Ada.Text_IO;

with VSS.JSON.Pull_Readers.Simple;
with VSS.JSON.Push_Writers;
with VSS.Stream_Element_Vectors.Conversions;
with VSS.Strings;
with VSS.Text_Streams.Memory_UTF8_Input;
with VSS.Text_Streams.Memory_UTF8_Output;

with Types.Inputs;
with Types.Outputs;

procedure Test_Constant_Aliases is
   use type Types.Integer_64;
   use type Types.Float_64;
   use type VSS.Strings.Virtual_String;

   Value : Types.Sample;

   procedure Assert (Condition : Boolean; Message : String);
   function Parse (JSON : String) return Boolean;
   function To_JSON return String;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Parse (JSON : String) return Boolean is
      Data : VSS.Stream_Element_Vectors.Stream_Element_Vector;
      Stream : aliased
        VSS.Text_Streams.Memory_UTF8_Input.Memory_UTF8_Input_Stream;
      Reader : VSS.JSON.Pull_Readers.Simple.JSON_Simple_Pull_Reader;
      Success : Boolean := True;
      Parsed : Types.Sample;
   begin
      for Item of JSON loop
         Data.Append (Ada.Streams.Stream_Element (Character'Pos (Item)));
      end loop;

      Stream.Set_Data (Data);
      Reader.Set_Stream (Stream'Unchecked_Access);
      Reader.Read_Next;
      Reader.Read_Next;
      Types.Inputs.Input_Sample (Reader, Parsed, Success);
      if Success then
         Value := Parsed;
      end if;

      return Success and then Reader.Is_End_Document;
   end Parse;

   function To_JSON return String is
      Stream : aliased
        VSS.Text_Streams.Memory_UTF8_Output.Memory_UTF8_Output_Stream;
      Writer : VSS.JSON.Push_Writers.JSON_Simple_Push_Writer;
   begin
      Writer.Set_Stream (Stream'Unchecked_Access);
      Writer.Start_Document;
      Types.Outputs.Output_Sample (Writer, Value);
      Writer.End_Document;
      return VSS.Stream_Element_Vectors.Conversions.Unchecked_To_String
        (Stream.Buffer);
   end To_JSON;

   Required_Fields : constant String :=
     """required_number"":1,""required_string"":""fixed""";
   Full : constant String :=
     "{" & Required_Fields
     & ",""optional_number"":1,""optional_string"":""fixed""}";
begin
   Assert (Parse (Full), "Valid referenced constants rejected");
   Assert (Value.optional_number.Is_Set, "Optional number not set");
   Assert (Value.optional_string = "fixed", "Optional string not set");
   Assert (To_JSON = Full, "Constant round trip failed");

   --  Fields remain editable, but the writer must emit schema constants.
   Value.required_number := Value.required_number + Value.required_number;
   Value.required_string := "changed";
   Value.optional_number.Value := Value.required_number;
   Value.optional_string := "changed";
   Assert (To_JSON = Full, "Writer lost referenced constants");

   Assert (Parse ("{" & Required_Fields & "}"), "Absent optional constants");
   Assert (not Value.optional_number.Is_Set, "Absent number marked as set");
   Assert (Value.optional_string.Is_Null, "Absent string marked as set");
   Assert
     (To_JSON = "{" & Required_Fields & "}", "Absent constants emitted");

   Assert
     (not Parse ("{""required_number"":2,""required_string"":""fixed""}"),
      "Wrong required number accepted");
   Assert
     (not Parse ("{""required_number"":1,""required_string"":""wrong""}"),
      "Wrong required string accepted");
   Assert
     (not Parse ("{" & Required_Fields & ",""optional_number"":2}"),
      "Wrong optional number accepted");
   Assert
     (not Parse ("{" & Required_Fields & ",""optional_string"":""wrong""}"),
      "Wrong optional string accepted");
   Assert
     (not Parse ("{" & Required_Fields & ",""optional_number"":null}"),
      "Null numeric constant accepted");
   Assert
     (not Parse ("{" & Required_Fields & ",""optional_string"":null}"),
      "Null string constant accepted");
   Assert
     (not Parse ("{" & Required_Fields & ",""optional_number"":""1""}"),
      "String in place of numeric constant accepted");
   Assert
     (not Parse ("{" & Required_Fields & ",""optional_string"":1}"),
      "Number in place of string constant accepted");

   Ada.Text_IO.Put_Line ("Constant aliases: PASS");
end Test_Constant_Aliases;
