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

with TypeScript.Types.Inputs;
with TypeScript.Types.Outputs;

procedure Test_TypeScript is

   use type TypeScript.Types.Channel_Variant;
   use type TypeScript.Types.Integer_64;
   use type TypeScript.Types.Scope;
   use type TypeScript.Types.Shape_Variant;
   use type VSS.Strings.Virtual_String;

   procedure Parse (JSON : String; Value : out TypeScript.Types.Message);
   --  Parse JSON as a Message, raise Program_Error on failure

   function To_JSON (Value : TypeScript.Types.Message) return String;
   --  Write Value as JSON text

   procedure Assert (Condition : Boolean; Message : String);
   --  Raise Program_Error with Message unless Condition

   ------------
   -- Assert --
   ------------

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   -----------
   -- Parse --
   -----------

   procedure Parse (JSON : String; Value : out TypeScript.Types.Message) is
      Data    : VSS.Stream_Element_Vectors.Stream_Element_Vector;
      Stream  : aliased
        VSS.Text_Streams.Memory_UTF8_Input.Memory_UTF8_Input_Stream;
      Reader  : VSS.JSON.Pull_Readers.Simple.JSON_Simple_Pull_Reader;
      Success : Boolean := True;
   begin
      for Item of JSON loop
         Data.Append (Ada.Streams.Stream_Element (Character'Pos (Item)));
      end loop;

      Stream.Set_Data (Data);
      Reader.Set_Stream (Stream'Unchecked_Access);
      Reader.Read_Next;
      Assert (Reader.Is_Start_Document, "Missing start of document");
      Reader.Read_Next;

      TypeScript.Types.Inputs.Input_Message (Reader, Value, Success);

      Assert
        (Success and then Reader.Is_End_Document, "Failed to parse " & JSON);
   end Parse;

   -------------
   -- To_JSON --
   -------------

   function To_JSON (Value : TypeScript.Types.Message) return String is
      Stream : aliased
        VSS.Text_Streams.Memory_UTF8_Output.Memory_UTF8_Output_Stream;
      Writer : VSS.JSON.Push_Writers.JSON_Simple_Push_Writer;
   begin
      Writer.Set_Stream (Stream'Unchecked_Access);
      Writer.Start_Document;
      TypeScript.Types.Outputs.Output_Message (Writer, Value);
      Writer.End_Document;

      return VSS.Stream_Element_Vectors.Conversions.Unchecked_To_String
        (Stream.Buffer);
   end To_JSON;

   --  The discriminator (`type`, `shape`) is not the first key, `nonce` is a
   --  union without discriminator, `author` is a nullable reference.
   Full : constant String :=
     "{""id"":""10"",""author"":null,"
     & """channel"":{""id"":""7"",""name"":null,""type"":1,"
     & """recipients"":[{""id"":""5"",""avatar"":null,""level"":2}]},"
     & """shape"":{""side"":3,""shape"":""square""},"
     & """layout"":1,""scope"":""messages.read"",""count"":5,"
     & """nonce"":""n"",""mentions"":[""1"",""2""],""levels"":[0,2],"
     & """extras"":[{""x"":1}],""0"":""zero"","
     & """application"":{""id"":""a""},"
     & """referenced_message"":{""id"":""9"","
     & """channel"":{""topic"":null,""id"":""8"",""type"":0},"
     & """shape"":{""shape"":""circle"",""radius"":2}}}";

   --  Output: keys are in the schema order, the discriminator constant is
   --  written, the nullable string and the always-null property are written
   --  as null, absent optional values (and null `topic`) are omitted.
   Expected : constant String :=
     "{""id"":""10"","
     & """channel"":{""type"":1,""id"":""7"",""name"":null,"
     & """recipients"":[{""id"":""5"",""avatar"":null,""level"":2}]},"
     & """shape"":{""shape"":""square"",""side"":3},"
     & """layout"":1,""scope"":""messages.read"",""count"":5,"
     & """nonce"":""n"",""mentions"":[""1"",""2""],""levels"":[0,2],"
     & """extras"":[{""x"":1}],""0"":""zero"","
     & """application"":{""id"":""a""},"
     & """referenced_message"":{""id"":""9"","
     & """channel"":{""type"":0,""id"":""8""},"
     & """shape"":{""shape"":""circle"",""radius"":2}}}";

   Value : TypeScript.Types.Message;
begin
   Parse (Full, Value);

   Assert (Value.id = "10", "id");
   Assert (not Value.author.Is_Set, "author");
   Assert
     (Value.channel.Union.Kind = TypeScript.Types.DMChannel_Variant,
      "channel kind");
   Assert
     (Value.channel.Union.DMChannel_Variant.recipients.Length = 1,
      "recipients");
   Assert
     (Value.channel.Union.DMChannel_Variant.recipients (1).avatar.Is_Null,
      "avatar");
   Assert
     (Value.channel.Union.DMChannel_Variant.recipients (1).level.Value = 2,
      "level");
   Assert
     (Value.shape.Union.Kind = TypeScript.Types.square_Variant, "shape kind");
   Assert (Value.shape.Union.square_Variant.side = 3, "side");
   Assert (Value.layout.Value = 1, "layout");
   Assert
     (Value.scope.Value = TypeScript.Types.messages_read, "scope");
   Assert (Value.count.Value = 5, "count");
   Assert (not Value.nonce.Is_Empty, "nonce");
   Assert (Value.mentions.Length = 2, "mentions");
   Assert (Value.levels.Length = 2 and then Value.levels (2) = 2, "levels");
   Assert (not Value.extras.Is_Empty, "extras");
   Assert (Value.Item_0 = "zero", "property 0");
   Assert (Value.application.Value.id = "a", "application");
   Assert (Value.referenced_message.Is_Set, "referenced_message");
   Assert
     (Value.referenced_message.Value.channel.Union.Kind
        = TypeScript.Types.TextChannel_Variant,
      "referenced channel kind");
   Assert
     (not Value.referenced_message.Value.referenced_message.Is_Set,
      "nested referenced_message");

   declare
      Output : constant String := To_JSON (Value);
   begin
      if Output /= Expected then
         Ada.Text_IO.Put_Line ("Expected: " & Expected);
         Ada.Text_IO.Put_Line ("Got:      " & Output);
         raise Program_Error with "Unexpected output";
      end if;
   end;

   --  A wrong discriminator value is rejected
   declare
      Is_Rejected : Boolean := False;
   begin
      begin
         Parse
           ("{""id"":""1"",""channel"":{""id"":""2"",""type"":5},"
            & """shape"":{""shape"":""circle"",""radius"":1}}",
            Value);
      exception
         when Program_Error =>
            Is_Rejected := True;
      end;

      Assert (Is_Rejected, "Unknown discriminator value is accepted");
   end;

   Ada.Text_IO.Put_Line ("OK");
end Test_TypeScript;
