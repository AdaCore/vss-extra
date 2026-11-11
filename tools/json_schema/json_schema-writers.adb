--
--  Copyright (C) 2022-2023, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Ada.Containers.Doubly_Linked_Lists;
with Ada.Wide_Wide_Text_IO;

with VSS.Characters;
with VSS.Strings.Character_Iterators;
with VSS.Strings.Conversions;
with VSS.Transformers.Casing;

package body JSON_Schema.Writers is

   Reserved_Words : constant VSS.String_Vectors.Virtual_String_Vector :=
     ["abort", "abs", "abstract", "accept", "access", "aliased", "all", "and",
      "array", "at", "begin", "body", "case", "constant", "declare", "delay",
      "delta", "digits", "do", "else", "elsif", "end", "entry", "exception",
      "exit", "for", "function", "generic", "goto", "if", "in", "interface",
      "is", "limited", "loop", "mod", "new", "not", "null", "of", "or",
      "others", "out", "overriding", "package", "pragma", "private",
      "procedure", "protected", "raise", "range", "record", "rem", "renames",
      "requeue", "return", "reverse", "select", "separate", "some", "subtype",
      "synchronized", "tagged", "task", "terminate", "then", "type", "until",
      "use", "when", "while", "with", "xor",
      "boolean"];

   Integer_Or_String : constant JSON_Schema.Simple_Type_Vectors.Vector :=
     [Definitions.An_Integer, Definitions.A_String];

   function Resolve
     (Map    : JSON_Schema.Readers.Schema_Map;
      Schema : Schema_Access) return Schema_Access;
   --  Follow $ref chain. Return null for unknown reference.

   function Find_Property
     (Schema : Schema_Access;
      Name   : VSS.Strings.Virtual_String) return Schema_Access;
   --  Return schema of the property with given Name or null

   -------------------
   -- Resolve_Alias --
   -------------------

   function Resolve_Alias
     (Map    : JSON_Schema.Readers.Schema_Map;
      Schema : Schema_Access) return Schema_Access
   is
      Result : Schema_Access := Schema;
   begin
      while not Result.Ref.Is_Empty
        and then Map.Contains (Result.Ref)
        and then Is_Alias (Map (Result.Ref))
      loop
         Result := Map (Result.Ref);
      end loop;

      return Result;
   end Resolve_Alias;

   function Is_Numeric_Const (Schema : Schema_Access) return Boolean is
     (Schema /= null
      and then not Schema.Const.Is_Empty
      and then Schema.Const.First_Element.Kind in
        VSS.JSON.Streams.Number_Value);
   --  Check if Schema has a numeric `const`

   String_Or_Null : constant JSON_Schema.Simple_Type_Vectors.Vector :=
     [Definitions.A_String, Definitions.A_Null];

   ---------------------------
   -- Each_Anonymous_Schema --
   ---------------------------

   procedure Each_Anonymous_Schema
     (Map    : JSON_Schema.Readers.Schema_Map;
      Schema : Schema_Access;
      Action : access procedure (Property : JSON_Schema.Property)) is
   begin
      --  Check direct properties for anonymous objects
      for Property of Schema.Properties loop
         if Property.Schema.Kind.Last_Index = 1 then
            case Property.Schema.Kind (1) is
               when Definitions.An_Object =>
                  --  Skip objects with additionalProperties (use Any_Object)
                  --  Skip objects without properties (use Any_Object)
                  if not (Property.Schema.Additional_Properties /= null
                    and then not
                      Property.Schema.Additional_Properties.Is_False)
                    and then not Property.Schema.Properties.Is_Empty
                  then
                     Action (Property);
                  end if;
               when others =>
                  null;
            end case;
         end if;
      end loop;

      for Used of Schema.All_Of loop
         for Property of Used.Properties loop
            if Property.Schema.Kind.Last_Index = 1 then
               case Property.Schema.Kind (1) is
                  when Definitions.An_Object =>
                     --  Skip objects with additionalProperties
                     --  Skip objects without properties (use Any_Object)
                     if not (Property.Schema.Additional_Properties /= null
                       and then not
                         Property.Schema.Additional_Properties.Is_False)
                       and then not Property.Schema.Properties.Is_Empty
                     then
                        Action (Property);
                     end if;
                  when others =>
                     null;
               end case;
            end if;
         end loop;
      end loop;

      for Used of Schema.Any_Of loop
         if Used.Kind.Last_Index = 1 then
            case Used.Kind (1) is
               when Definitions.An_Object =>
                  Action
                    ((Escape_Keywords
                       (Variant_Name (Map, Used, Schema.X_Discriminator)),
                     Used));
               when others =>
                  null;
            end case;
         end if;
      end loop;
   end Each_Anonymous_Schema;

   ---------------------------
   -- Each_Enumeration_Type --
   ---------------------------

   procedure Each_Enumeration_Type
     (Map      : JSON_Schema.Readers.Schema_Map;
      Optional : String_Sets.Set;
      Action   : access procedure
        (Name     : Schema_Name;
         Property : VSS.Strings.Virtual_String;
         Schema   : Schema_Access;
         Optional : Boolean))
   is

      procedure Traverse_Nested_Schemas
        (Name     : Schema_Name;
         Property : VSS.Strings.Virtual_String;
         Schema   : Schema_Access;
         Optional : Boolean);
      --  Traverse all types in Schema recursively, find enumeration schemes
      --  and call Action for them. Name is toppest named schema, while
      --  Property (if not empty) is a property corresponding to Schema.

      -----------------------------
      -- Traverse_Nested_Schemas --
      -----------------------------

      procedure Traverse_Nested_Schemas
        (Name     : Schema_Name;
         Property : VSS.Strings.Virtual_String;
         Schema   : Schema_Access;
         Optional : Boolean) is
      begin
         if Is_Enum (Schema) then
            Action (Name, Property, Schema, Optional);
         end if;

         for Item of Schema.All_Of loop
            if Item.Ref.Is_Empty then
               Traverse_Nested_Schemas (Name, Property, Item, True);
            end if;
         end loop;

         for Item of Schema.Any_Of loop
            if Item.Ref.Is_Empty then
               Traverse_Nested_Schemas (Name, Property, Item, True);
            end if;
         end loop;

         for Item of Schema.Items loop
            if Item.Ref.Is_Empty then
               Traverse_Nested_Schemas (Name, Property, Item, False);
            end if;
         end loop;

         for Property of Schema.Properties loop
            Traverse_Nested_Schemas
              (Name,
               Property.Name,
               Property.Schema,
               not Schema.Required.Contains (Property.Name));
         end loop;
      end Traverse_Nested_Schemas;

   begin
      for Cursor in Map.Iterate loop
         declare
            Name : constant Schema_Name :=
              JSON_Schema.Readers.Schema_Maps.Key (Cursor);

            Schema : constant Schema_Access :=
              JSON_Schema.Readers.Schema_Maps.Element (Cursor);

            Type_Name : constant VSS.Strings.Virtual_String :=
              Ref_To_Type_Name (Name);
         begin
            Traverse_Nested_Schemas
              (Name,
               "",
               Schema,
               Optional.Contains (Type_Name));
         end;
      end loop;
   end Each_Enumeration_Type;

   ----------------------
   -- Each_Holder_Type --
   ----------------------

   procedure Each_Holder_Type
     (Map      : JSON_Schema.Readers.Schema_Map;
      Holders  : VSS.String_Vectors.Virtual_String_Vector;
      Action   : access procedure (Name : Schema_Name))
   is
      Done : String_Sets.Set;
   begin
      for Item of Holders loop
         declare
            use type VSS.Strings.Virtual_String;

            Pair   : constant VSS.String_Vectors.Virtual_String_Vector :=
              Item.Split (Separator => ':');

            Schema : constant Schema_Access := Map (Pair (1));
         begin
            for Property of Schema.Properties loop
               if Property.Name = Pair (2) then
                  declare
                     Name : constant Schema_Name := Property.Schema.Ref;
                  begin
                     if not Done.Contains (Name) then
                        Action (Name);
                        Done.Include (Name);
                     end if;
                  end;
               end if;
            end loop;
         end;
      end loop;
   end Each_Holder_Type;

   -------------------
   -- Each_Property --
   -------------------

   procedure Each_Property
     (Map    : JSON_Schema.Readers.Schema_Map;
      Name   : Schema_Name;
      Schema : Schema_Access;
      Action : access procedure
        (Enclosing : Schema_Name;
         Property  : JSON_Schema.Property;
         Required  : Boolean))
   is
      use type VSS.Strings.Virtual_String;

      type Property_Info is record
         Schema   : Schema_Name;
         Property : JSON_Schema.Property;
      end record;

      function Equal_Name (Left, Right : Property_Info)
        return Boolean is (Left.Property.Name = Right.Property.Name);

      package Property_Lists is new Ada.Containers.Doubly_Linked_Lists
        (Property_Info, Equal_Name);

      procedure Prepend
        (List     : in out Property_Lists.List;
         Schema   : Schema_Name;
         Property : JSON_Schema.Property);
      --  If property in the list, then move it at the beginning, otherwise
      --  prepend it to the list.

      -------------
      -- Prepend --
      -------------

      procedure Prepend
        (List     : in out Property_Lists.List;
         Schema   : Schema_Name;
         Property : JSON_Schema.Property)
      is
         Cursor : Property_Lists.Cursor := List.Find (("", Property));
      begin
         if Property_Lists.Has_Element (Cursor) then
            declare
               Value : constant Property_Info :=
                 Property_Lists.Element (Cursor);
            begin
               List.Delete (Cursor);
               List.Prepend (Value);
            end;
         else
            List.Prepend ((Schema, Property));
         end if;
      end Prepend;

      List : Property_Lists.List;
      --  A list of collected properties. Items in the list are ordered.
      --  If we found a property in a parent schema then we move the property
      --  to the beginning of the list instead of creating a new one.

      Required : String_Sets.Set;
      --  Set of required properties

      Next : Schema_Access := Schema;

      Enclosing : Schema_Name := Name;  --  Name of Next
   begin
      loop
         for Property of reverse Next.Properties loop
            Prepend (List, Enclosing, Property);

            if Next.Required.Contains (Property.Name) then
               Required.Include (Property.Name);
            end if;
         end loop;

         for Item of Next.All_Of loop
            for Property of reverse Item.Properties loop
               Prepend (List, Enclosing, Property);

               if Item.Required.Contains (Property.Name) then
                  Required.Include (Property.Name);
               end if;
            end loop;
         end loop;

         if Next.All_Of.Is_Empty then
            exit;
         else
            Enclosing := Next.All_Of.First_Element.Ref;
            Next := Map (Enclosing);
         end if;
      end loop;

      for Item of List loop
         Action
           (Item.Schema,
            Item.Property,
            Required.Contains (Item.Property.Name));
      end loop;
   end Each_Property;

   ---------------------
   -- Each_Union_Type --
   ---------------------

   procedure Each_Union_Type
     (Map      : JSON_Schema.Readers.Schema_Map;
      Optional : String_Sets.Set;
      Action   : access procedure
        (Name     : Schema_Name;
         Property : VSS.Strings.Virtual_String;
         Schema   : Schema_Access;
         Optional : Boolean))
   is

      procedure Traverse_Nested_Schemas
        (Name     : Schema_Name;
         Property : VSS.Strings.Virtual_String;
         Schema   : Schema_Access;
         Optional : Boolean);
      --  Traverse all types in Schema recursively, find anyOf schemes
      --  and call Action for them. Name is toppest named schema, while
      --  Property (if not empty) is a property corresponding to Schema.

      -----------------------------
      -- Traverse_Nested_Schemas --
      -----------------------------

      procedure Traverse_Nested_Schemas
        (Name     : Schema_Name;
         Property : VSS.Strings.Virtual_String;
         Schema   : Schema_Access;
         Optional : Boolean)
      is
      begin
         if Is_Union_Type (Schema) then
            Action (Name, Property, Schema, Optional);
         end if;

         for Item of Schema.All_Of loop
            if Item.Ref.Is_Empty then
               Traverse_Nested_Schemas (Name, Property, Item, True);
            end if;
         end loop;

         for Property of Schema.Properties loop
            Traverse_Nested_Schemas
              (Name,
               Property.Name,
               Property.Schema,
               not Schema.Required.Contains (Property.Name));
         end loop;
      end Traverse_Nested_Schemas;

   begin
      for Cursor in Map.Iterate loop
         declare
            Name : constant Schema_Name :=
              JSON_Schema.Readers.Schema_Maps.Key (Cursor);

            Schema : constant Schema_Access :=
              JSON_Schema.Readers.Schema_Maps.Element (Cursor);

            Type_Name : constant VSS.Strings.Virtual_String :=
              Ref_To_Type_Name (Name);
         begin
            Traverse_Nested_Schemas
              (Name,
               "",
               Schema,
               Optional.Contains (Type_Name));
         end;
      end loop;
   end Each_Union_Type;

   ---------------------
   -- Escape_Keywords --
   ---------------------

   function Escape_Keywords (Name : VSS.Strings.Virtual_String)
     return VSS.Strings.Virtual_String
   is
      use type VSS.Strings.Virtual_String;

      function Replace_Invalid
        (Text : VSS.Strings.Virtual_String) return VSS.Strings.Virtual_String;
      --  Replace any character not allowed in an identifier (like space or
      --  dot) with underscore, collapse repeated underscores and drop the
      --  trailing one.

      ---------------------
      -- Replace_Invalid --
      ---------------------

      function Replace_Invalid
        (Text : VSS.Strings.Virtual_String) return VSS.Strings.Virtual_String
      is
         Result  : VSS.Strings.Virtual_String;
         Pending : Boolean := False;
         Char    : VSS.Characters.Virtual_Character'Base;
         Cursor  : VSS.Strings.Character_Iterators.Character_Iterator :=
           Text.Before_First_Character;
      begin
         while Cursor.Forward (Char) loop
            if Char in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' then
               if Pending and not Result.Is_Empty then
                  Result.Append ('_');
               end if;

               Pending := False;
               Result.Append (Char);
            else
               Pending := True;
            end if;
         end loop;

         return Result;
      end Replace_Invalid;

   begin
      if Name.Is_Empty then
         return Name;
      elsif Name.At_First_Character.Element not in 'A' .. 'Z' | 'a' .. 'z' then
         --  Trim any non-alpha character at the begining of Name
         declare
            Char   : VSS.Characters.Virtual_Character'Base;
            Cursor : VSS.Strings.Character_Iterators.Character_Iterator :=
              Name.At_First_Character;
         begin
            while Cursor.Forward (Char) loop
               exit when Char in 'A' .. 'Z' | 'a' .. 'z';
            end loop;

            if Cursor.Has_Element then
               return Escape_Keywords
                 (Name.Slice (Cursor, Name.At_Last_Character));
            else
               --  No letters at all, like "0"
               return "Item_" & Replace_Invalid (Name);
            end if;
         end;
      elsif not Reserved_Words.Contains (Name) then
         return Replace_Invalid (Name);
      elsif Name.Starts_With ("i") or Name.Starts_With ("a") then
         return "an_" & Name;
      else
         return "a_" & Name;
      end if;
   end Escape_Keywords;

   ----------------------
   -- Get_Element_Type --
   ----------------------

   procedure Get_Element_Type
     (Name         : Schema_Name;
      Map          : JSON_Schema.Readers.Schema_Map;
      Prop         : Property;
      Enum_Package : VSS.Strings.Virtual_String;
      Type_Name    : out VSS.Strings.Virtual_String;
      Prefix       : out VSS.Strings.Virtual_String)
   is
      use VSS.Strings;

      Schema : constant Schema_Access := Prop.Schema;

      Enum_Prefix : constant VSS.Strings.Virtual_String :=
        (if Enum_Package.Is_Empty then Empty_Virtual_String
         else Enum_Package & To_Virtual_String ("."));
   begin
      if Schema.Kind.Last_Index = 1 then
         case Schema.Kind (1) is
            when Definitions.An_Array =>

               if Is_Enum (Schema.Items.First_Element) then
                  Type_Name := Ref_To_Type_Name (Name);
                  Type_Name.Append ("_");
                  Type_Name.Append (Prop.Name);
                  Prefix := Enum_Prefix;

               else
                  Get_Field_Type
                    (Map, Schema.Items.First_Element,
                     True, "", Enum_Package, Type_Name, Prefix);

                  if Type_Name.Is_Empty then
                     Type_Name := "Virtual_String";
                     Prefix := "VSS.Strings.";
                  end if;
               end if;
            when others =>
               null;
         end case;
      end if;
   end Get_Element_Type;

   --------------------
   -- Get_Field_Type --
   --------------------

   procedure Get_Field_Type
     (Map          : JSON_Schema.Readers.Schema_Map;
      Schema       : Schema_Access;
      Required     : Boolean;
      Fallback     : VSS.Strings.Virtual_String;
      Enum_Package : VSS.Strings.Virtual_String;
      Type_Name    : out VSS.Strings.Virtual_String;
      Prefix       : out VSS.Strings.Virtual_String)
   is
      use type JSON_Schema.Simple_Type_Vectors.Vector;
      use VSS.Strings;

      Result : VSS.Strings.Virtual_String :=
        (if Required then Empty_Virtual_String
         else "Optional_");

      Enum_Prefix : constant VSS.Strings.Virtual_String :=
        (if Enum_Package.Is_Empty then Empty_Virtual_String
         else Enum_Package & To_Virtual_String ("."));
   begin
      if Resolve_Alias (Map, Schema) /= Schema then
         --  No Ada type is declared for an alias (like `Snowflake = string`
         --  or a reference to another type), so use the aliased type.
         declare
            Target : constant Schema_Access := Resolve_Alias (Map, Schema);
         begin
            if Is_Numeric_Const (Target) then
               --  Keep referenced constants as fields. Property readers and
               --  writers enforce the constant from the aliased schema.
               if Target.Kind.Contains (Definitions.A_Number) then
                  Result.Append ("Float_64");
               else
                  Result.Append ("Integer_64");
               end if;

               Type_Name := Result;
            elsif not Target.Const.Is_Empty
              and then Target.Kind.Contains (Definitions.A_String)
            then
               Type_Name := "Virtual_String";
               Prefix := "VSS.Strings.";
            else
               Get_Field_Type
                 (Map, Target, Required, Fallback, Enum_Package,
                  Type_Name, Prefix);
            end if;
         end;

         return;
      elsif not Schema.Ref.Is_Empty then
         Result.Append (Ref_To_Type_Name (Schema.Ref));

         if Is_Enum (Map (Schema.Ref)) then
            Prefix := Enum_Prefix;
         end if;

      elsif Is_Null_Only (Schema) then
         --  Null-only properties carry no data and need no record component.
         Result := VSS.Strings.Empty_Virtual_String;

      elsif Is_Enum (Schema) then

         if Schema.Enum.Length = 1 then
            Result := VSS.Strings.Empty_Virtual_String;

         else
            Result.Append (Fallback);
            Prefix := Enum_Prefix;
         end if;

      elsif Schema.Additional_Properties /= null and then not
         Schema.Additional_Properties.Is_False
      then
         Result := "Any_Object";  --  TODO: Make more precise type???
      elsif Schema.Kind.Last_Index = 7 then
         Result := "Any_Value";
      elsif Schema.Kind = Integer_Or_String then
         Result.Append ("Integer_Or_String");
      elsif Schema.Kind = String_Or_Null then
         --  To represent `null` (and an absent value) it uses Is_Null
         --  function, so there is no Optional_ variant.
         Result := "Virtual_String";
         Prefix := "VSS.Strings.";
      elsif Schema.Kind.Last_Index = 1 then
         case Schema.Kind (1) is
            when Definitions.A_Boolean =>
               --  Let's don't use Optional_Boolean because
               --  all absent boolean fields work as False
               Result := "Boolean";

            when Definitions.An_Integer =>
               if Required and Is_Numeric_Const (Schema) then
                  --  A constant property (like discriminator), skip it
                  Result := VSS.Strings.Empty_Virtual_String;
               else
                  Result.Append ("Integer_64");
               end if;

            when Definitions.A_Null =>
               raise Program_Error;  --  Handled above

            when Definitions.A_Number =>
               if Required and Is_Numeric_Const (Schema) then
                  Result := VSS.Strings.Empty_Virtual_String;
               else
                  Result.Append ("Float_64");
               end if;

            when Definitions.A_String =>

               if Required and
                 (Schema.Enum.Length = 1
                  or Schema.X_Enum.Length = 1
                  or not Schema.Const.Is_Empty)
               then
                  --  If string type redefined as an enum with just one literal
                  --  then skip this property by returning an empty type name.
                  Result := VSS.Strings.Empty_Virtual_String;
               elsif Is_Enum (Schema) then
                  Prefix := Enum_Prefix;
                  Result.Append (Fallback);
               else
                  --  Instead of Optional_String use just Virtual_String,
                  --  to check for an absent value use Is_Null.
                  Result := "Virtual_String";
                  Prefix := "VSS.Strings.";
               end if;

            when Definitions.An_Array =>
               declare
                  Item : constant Schema_Access :=
                    Resolve_Alias (Map, Schema.Items.First_Element);
               begin
                  --  TODO: Optional vectors???
                  if not Item.Ref.Is_Empty
                    and then Map.Contains (Item.Ref)
                    and then Is_Untyped_Object (Map (Item.Ref))
                  then
                     --  Elements are tagged (derived from Any_Object), so
                     --  vector operations would be primitive for two tagged
                     --  types. Keep the whole array as Any_Value instead.
                     Result := "Any_Value";

                  elsif not Item.Ref.Is_Empty then
                     Result := Ref_To_Type_Name (Item.Ref);
                     Result.Append ("_Vector");

                  elsif Is_Enum (Item) then
                     Result := Fallback;
                     Result.Append ("_Vector");

                  else
                     case Item.Kind (1) is
                        when Definitions.A_Boolean =>
                           Result := "Boolean_Vector";

                        when Definitions.An_Integer =>
                           Result := "Integer_64_Vector";

                        when Definitions.A_Null
                           | Definitions.An_Array
                           | Definitions.An_Object =>
                           raise Program_Error;

                        when Definitions.A_Number =>
                           Result := "Float_64_Vector";

                        when Definitions.A_String =>
                           Result := "Virtual_String_Vector";
                           Prefix := "VSS.String_Vectors.";
                     end case;
                  end if;
               end;

            when Definitions.An_Object =>
               --  If object has no properties, use Any_Object
               if Schema.Properties.Is_Empty then
                  Result := "Any_Object";
               else
                  Result.Append (Fallback);
               end if;
         end case;
      else
         --  No type at all (like `{}`), any value is allowed
         Result := "Any_Value";
      end if;

      Type_Name := Result;
   end Get_Field_Type;

   ---------------------
   -- Is_Holder_Field --
   ---------------------

   function Is_Holder_Field
     (Name     : Schema_Name;
      Property : VSS.Strings.Virtual_String;
      Holders  : VSS.String_Vectors.Virtual_String_Vector) return Boolean
   is
      use type VSS.Strings.Virtual_String;
   begin
      return Holders.Contains (Name & ":" & Property);
   end Is_Holder_Field;

   -------------------
   -- Is_Union_Type --
   -------------------

   function Is_Union_Type (Schema : Schema_Access) return Boolean is
     (not (for all S of Schema.Any_Of => S.Is_True and S.Ref.Is_Empty));

   --------------
   -- New_Line --
   --------------

   procedure New_Line is
   begin
      Ada.Wide_Wide_Text_IO.New_Line;
   end New_Line;

   ------------------
   -- Print_Vector --
   ------------------

   procedure Print_Vector
     (Header : VSS.String_Vectors.Virtual_String_Vector) is
   begin
      for Item of Header loop
         Put (Item);
         New_Line;
      end loop;
   end Print_Vector;

   ---------
   -- Put --
   ---------

   procedure Put (Text : VSS.Strings.Virtual_String) is
   begin
      Ada.Wide_Wide_Text_IO.Put
        (VSS.Strings.Conversions.To_Wide_Wide_String (Text));
   end Put;

   ----------------------
   -- Ref_To_Type_Name --
   ----------------------

   function Ref_To_Type_Name (Subschema : Schema_Name)
     return VSS.Strings.Virtual_String
   is
      function To_Identifier
        (Name : VSS.Strings.Virtual_String) return VSS.Strings.Virtual_String;
      --  Replace any sequence of characters that is not allowed in Ada
      --  identifier with a single underscore (schemas generated from
      --  TypeScript have names like `Omit<Type,"key">`).

      -------------------
      -- To_Identifier --
      -------------------

      function To_Identifier
        (Name : VSS.Strings.Virtual_String) return VSS.Strings.Virtual_String
      is
         Result  : VSS.Strings.Virtual_String;
         Pending : Boolean := False;
         Char    : VSS.Characters.Virtual_Character'Base;
         Cursor  : VSS.Strings.Character_Iterators.Character_Iterator :=
           Name.Before_First_Character;
      begin
         while Cursor.Forward (Char) loop
            if Char in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' then
               if Pending and not Result.Is_Empty then
                  Result.Append ('_');
               end if;

               Pending := False;
               Result.Append (Char);
            else
               Pending := True;
            end if;
         end loop;

         return Result;
      end To_Identifier;

      List : constant VSS.String_Vectors.Virtual_String_Vector :=
        Subschema.Split ('/');
   begin
      return Escape_Keywords (To_Identifier (List.Element (List.Length)));
   end Ref_To_Type_Name;


   -----------------
   -- Const_Image --
   -----------------

   function Const_Image
     (Schema : Schema_Access) return VSS.Strings.Virtual_String
   is
      use all type VSS.JSON.Streams.JSON_Stream_Element_Kind;
      use type VSS.JSON.JSON_Number_Kind;
   begin
      if Schema = null then
         return VSS.Strings.Empty_Virtual_String;
      elsif not Schema.Const.Is_Empty then
         declare
            Item : constant VSS.JSON.Streams.JSON_Stream_Element :=
              Schema.Const.First_Element;
         begin
            case Item.Kind is
               when String_Value =>
                  return Item.String_Value;
               when Number_Value =>
                  if Item.Number_Value.Kind = VSS.JSON.JSON_Integer then
                     declare
                        Image : constant Wide_Wide_String :=
                          Item.Number_Value.Integer_Value'Wide_Wide_Image;
                     begin
                        return VSS.Strings.To_Virtual_String
                          (if Image (Image'First) = ' '
                           then Image (Image'First + 1 .. Image'Last)
                           else Image);
                     end;
                  end if;
               when others =>
                  null;
            end case;
         end;
      elsif Schema.Enum.Length = 1 then
         return Schema.Enum.First_Element;
      end if;

      return VSS.Strings.Empty_Virtual_String;
   end Const_Image;

   -------------------
   -- Find_Property --
   -------------------

   function Find_Property
     (Schema : Schema_Access;
      Name   : VSS.Strings.Virtual_String) return Schema_Access
   is
      use type VSS.Strings.Virtual_String;
   begin
      if Schema /= null then
         for Property of Schema.Properties loop
            if Property.Name = Name then
               return Property.Schema;
            end if;
         end loop;
      end if;

      return null;
   end Find_Property;

   -------------------------------
   -- Has_Numeric_Discriminator --
   -------------------------------

   function Has_Numeric_Discriminator
     (Map    : JSON_Schema.Readers.Schema_Map;
      Schema : Schema_Access) return Boolean is
   begin
      return not Schema.X_Discriminator.Is_Empty
        and then not Schema.Any_Of.Is_Empty
        and then Is_Numeric_Const
          (Find_Property
             (Resolve (Map, Schema.Any_Of.First_Element),
              Schema.X_Discriminator));
   end Has_Numeric_Discriminator;

   --------------------
   -- Prepare_Unions --
   --------------------

   procedure Prepare_Unions
     (Map  : JSON_Schema.Readers.Schema_Map;
      Root : Schema_Access)
   is
      function Find_Discriminator
        (Schema : Schema_Access) return VSS.Strings.Virtual_String;
      --  Find a property with distinct constant values in each variant

      procedure Prepare
        (Name     : VSS.Strings.Virtual_String;
         Schema   : Schema_Access;
         Is_Named : Boolean);

      ------------------------
      -- Find_Discriminator --
      ------------------------

      function Find_Discriminator
        (Schema : Schema_Access) return VSS.Strings.Virtual_String
      is
         First : constant Schema_Access :=
           Resolve (Map, Schema.Any_Of.First_Element);
      begin
         if First = null then
            return VSS.Strings.Empty_Virtual_String;
         end if;

         for Candidate of First.Properties loop
            if not Const_Image (Candidate.Schema).Is_Empty then
               declare
                  Values : VSS.String_Vectors.Virtual_String_Vector;
                  Found  : Boolean := True;
               begin
                  for Item of Schema.Any_Of loop
                     declare
                        Value : constant VSS.Strings.Virtual_String :=
                          Const_Image
                            (Find_Property
                               (Resolve (Map, Item), Candidate.Name));
                     begin
                        if Value.Is_Empty or else Values.Contains (Value) then
                           Found := False;
                           exit;
                        end if;

                        Values.Append (Value);
                     end;
                  end loop;

                  if Found then
                     return Candidate.Name;
                  end if;
               end;
            end if;
         end loop;

         return VSS.Strings.Empty_Virtual_String;
      end Find_Discriminator;

      -------------
      -- Prepare --
      -------------

      procedure Prepare
        (Name     : VSS.Strings.Virtual_String;
         Schema   : Schema_Access;
         Is_Named : Boolean)
      is
         use type VSS.Strings.Virtual_String;
      begin
         if Schema = null then
            return;
         end if;

         if not Schema.Any_Of.Is_Empty and then Is_Union_Type (Schema) then
            Schema.X_Discriminator := Find_Discriminator (Schema);

            if Schema.X_Discriminator.Is_Empty then
               Ada.Wide_Wide_Text_IO.Put_Line
                 (Ada.Wide_Wide_Text_IO.Standard_Error,
                  VSS.Strings.Conversions.To_Wide_Wide_String (Name)
                  & ": no discriminator in anyOf, use Any_Value");

               Schema.Any_Of.Clear;
               Schema.One_Of.Clear;
               Schema.Kind.Clear;

               if Is_Named then
                  --  Named type is declared as `new Any_Object`
                  Schema.Kind.Append (Definitions.An_Object);
               else
                  --  Any type means Any_Value
                  for Kind in Definitions.Simple_Types loop
                     Schema.Kind.Append (Kind);
                  end loop;
               end if;
            end if;
         end if;

         for Item of Schema.All_Of loop
            Prepare (Name, Item, False);
         end loop;

         for Item of Schema.Any_Of loop
            Prepare (Name, Item, False);
         end loop;

         for Item of Schema.Items loop
            Prepare (Name, Item, False);
         end loop;

         Prepare (Name, Schema.Additional_Properties, False);

         for Property of Schema.Properties loop
            Prepare (Name & "/" & Property.Name, Property.Schema, False);
         end loop;
      end Prepare;
   begin
      for Cursor in Map.Iterate loop
         Prepare
           (JSON_Schema.Readers.Schema_Maps.Key (Cursor),
            JSON_Schema.Readers.Schema_Maps.Element (Cursor),
            True);
      end loop;

      Prepare ("#", Root, True);
   end Prepare_Unions;

   -------------
   -- Resolve --
   -------------

   function Resolve
     (Map    : JSON_Schema.Readers.Schema_Map;
      Schema : Schema_Access) return Schema_Access
   is
      Result : Schema_Access := Schema;
   begin
      while Result /= null and then not Result.Ref.Is_Empty loop
         if not Map.Contains (Result.Ref) then
            return null;
         end if;

         Result := Map (Result.Ref);
      end loop;

      return Result;
   end Resolve;

   ------------------
   -- Variant_Name --
   ------------------

   function Variant_Name
     (Map    : JSON_Schema.Readers.Schema_Map;
      Schema : Schema_Access;
      Key    : VSS.Strings.Virtual_String := "")
      return VSS.Strings.Virtual_String
   is
      use type VSS.Strings.Virtual_String;
      use all type VSS.JSON.Streams.JSON_Stream_Element_Kind;

   begin
      if not Key.Is_Empty then
         declare
            Property : constant Schema_Access :=
              Find_Property (Resolve (Map, Schema), Key);
         begin
            if not Is_Numeric_Const (Property) then
               declare
                  use VSS.Transformers.Casing;

                  Name : constant VSS.Strings.Virtual_String :=
                    Const_Image (Property);
               begin
                  if not Has_Enum_Package then
                     --  Variant enumeration literal is declared in the same
                     --  package as types, avoid a conflict with type names
                     for Cursor in Map.Iterate loop
                        if To_Lowercase.Transform
                          (Ref_To_Type_Name
                             (JSON_Schema.Readers.Schema_Maps.Key (Cursor)))
                          = To_Lowercase.Transform (Escape_Keywords (Name))
                        then
                           return Name & "_Variant";
                        end if;
                     end loop;
                  end if;

                  return Name;
               end;
            elsif not Schema.Ref.Is_Empty then
               --  Numeric value is not an identifier, use the type name
               return Ref_To_Type_Name (Schema.Ref) & "_Variant";
            else
               return Key & "_" & Const_Image (Property);
            end if;
         end;
      elsif Schema.Ref.Is_Empty then
         for Property of Schema.Properties loop
            --  Look for the first string `const` property. A single-item
            --  `enum` is a widely used (e.g. by OpenAPI-flavored schemas)
            --  equivalent of `const` and is treated the same way elsewhere
            --  in this tool (see Get_Field_Type / Write_Record_Component).
            if not Property.Schema.Const.Is_Empty and then
              Property.Schema.Const.First_Element.Kind = String_Value
            then

               return Property.Schema.Const.First_Element.String_Value;

            elsif Property.Schema.Enum.Length = 1 then

               return Property.Schema.Enum.First_Element;
            end if;
         end loop;

         raise Program_Error with "No const found in anyOf item.";
      else
         return Variant_Name (Map, Map (Schema.Ref));
      end if;
   end Variant_Name;

   -------------------
   -- Variant_Value --
   -------------------

   function Variant_Value
     (Map    : JSON_Schema.Readers.Schema_Map;
      Schema : Schema_Access;
      Key    : VSS.Strings.Virtual_String) return VSS.Strings.Virtual_String
   is
   begin
      if Key.Is_Empty then
         return Variant_Name (Map, Schema);
      else
         return Const_Image (Find_Property (Resolve (Map, Schema), Key));
      end if;
   end Variant_Value;

end JSON_Schema.Writers;
