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
with VSS.String_Vectors;
with VSS.Strings.Conversions;
with VSS.Text_Streams.Memory_UTF8_Input;
with VSS.Text_Streams.Memory_UTF8_Output;

with Types.Inputs;
with Types.Outputs;

procedure Test_Null_Properties is
   use type VSS.Strings.Virtual_String;

   --  This aggregate also checks that null-only properties have no fields.
   Value : Types.Sample := (null record);

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
   begin
      for Item of JSON loop
         Data.Append (Ada.Streams.Stream_Element (Character'Pos (Item)));
      end loop;

      Stream.Set_Data (Data);
      Reader.Set_Stream (Stream'Unchecked_Access);
      Reader.Read_Next;
      Reader.Read_Next;
      Types.Inputs.Input_Sample (Reader, Value, Success);
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

   Expected : constant String :=
     "{""required_null"":null,""required_ref"":null}";
   Properties : constant VSS.String_Vectors.Virtual_String_Vector :=
     ["required_null", "required_ref", "optional_null", "optional_ref"];
   Invalid_Values : constant VSS.String_Vectors.Virtual_String_Vector :=
     ["""text""", "1", "1.5", "true", "{}", "[]"];
begin
   Assert (To_JSON = Expected, "Required null properties not emitted");
   Assert (Parse (Expected), "Valid required null properties rejected");
   Assert (To_JSON = Expected, "Null properties failed to round trip");
   Assert
     (Parse
        ("{""required_null"":null,""required_ref"":null,"
         & """optional_null"":null,""optional_ref"":null}"),
      "Valid optional null properties rejected");
   Assert (To_JSON = Expected, "Optional null properties emitted");

   for Invalid of Invalid_Values loop
      for Property of Properties loop
         declare
            JSON : VSS.Strings.Virtual_String := "{";
         begin
            for Field of Properties loop
               if JSON /= "{" then
                  JSON.Append (",");
               end if;

               JSON.Append
                 ("""" & Field & """:"
                  & (if Field = Property then Invalid else "null"));
            end loop;

            JSON.Append ("}");
            Assert
              (not Parse (VSS.Strings.Conversions.To_UTF_8_String (JSON)),
               "Non-null value accepted: "
               & VSS.Strings.Conversions.To_UTF_8_String (JSON));
         end;
      end loop;
   end loop;

   Ada.Text_IO.Put_Line ("Null properties: PASS (24 rejected values)");
end Test_Null_Properties;
