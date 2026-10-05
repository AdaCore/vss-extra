with Ada.Streams;
with Ada.Text_IO;

with VSS.JSON.Pull_Readers.Simple;
with VSS.Stream_Element_Vectors;
with VSS.Text_Streams.Memory_UTF8_Input;

with Boolean_Defaults.Types.Inputs;

procedure Test_Boolean_Defaults is

   procedure Check
     (JSON        : String;
      Enabled     : Boolean;
      Disabled    : Boolean;
      Unspecified : Boolean);

   procedure Check
     (JSON        : String;
      Enabled     : Boolean;
      Disabled    : Boolean;
      Unspecified : Boolean)
   is
      Data    : VSS.Stream_Element_Vectors.Stream_Element_Vector;
      Stream  : aliased
        VSS.Text_Streams.Memory_UTF8_Input.Memory_UTF8_Input_Stream;
      Reader  : VSS.JSON.Pull_Readers.Simple.JSON_Simple_Pull_Reader;
      Value   : Boolean_Defaults.Types.Settings;
      Success : Boolean := True;
   begin
      for Item of JSON loop
         Data.Append (Ada.Streams.Stream_Element (Character'Pos (Item)));
      end loop;

      Stream.Set_Data (Data);
      Reader.Set_Stream (Stream'Unchecked_Access);
      Reader.Read_Next;
      if not Reader.Is_Start_Document then
         raise Program_Error with "Missing start of document";
      end if;
      Reader.Read_Next;

      Boolean_Defaults.Types.Inputs.Input_Settings (Reader, Value, Success);

      if not Success or else not Reader.Is_End_Document then
         raise Program_Error with "Failed to parse " & JSON;
      elsif Value.Enabled /= Enabled
        or else Value.Disabled /= Disabled
        or else Value.Unspecified /= Unspecified
      then
         raise Program_Error with "Incorrect boolean defaults for " & JSON;
      end if;
   end Check;

begin
   Check ("{}", True, False, False);
   Check ("{""enabled"":false}", False, False, False);
   Check ("{""enabled"":true}", True, False, False);
   Check ("{""disabled"":true,""unspecified"":true}", True, True, True);
   Check
     ("{""enabled"":false,""disabled"":false,""unspecified"":false}",
      False, False, False);
   Ada.Text_IO.Put_Line ("Boolean defaults: PASS (5 cases)");
end Test_Boolean_Defaults;
