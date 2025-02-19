defmodule ExDoc.Retriever.ErlangTest do
  use ExUnit.Case, async: true
  alias ExDoc.{Retriever, DocAST, Language.Erlang}
  import TestHelper

  @moduletag :tmp_dir

  describe "docs_from_modules/2" do
    @describetag :otp_eep59

    test "module with no docs is generated", c do
      erlc(c, :mod, ~S"""
      -module(mod).
      """)

      assert {[_], []} = Retriever.docs_from_modules([:mod], %ExDoc.Config{})
    end

    test "module with no chunk", c do
      erlc(
        c,
        :no_chunk,
        ~S"""
        -module(no_chunk).
        """,
        docs: false
      )

      assert {[], []} = Retriever.docs_from_modules([:no_chunk], %ExDoc.Config{})
    end

    test "module", c do
      erlc(c, :mod, ~S"""
      -module(mod).
      -moduledoc("mod docs.").
      -export([function1/0, function2/0]).

      -doc("function1/0 docs.").
      -spec function1() -> atom().
      function1() -> ok.

      -doc("function2/0 docs.").
      function2() -> ok.
      """)

      {[mod], []} = Retriever.docs_from_modules([:mod], %ExDoc.Config{})

      %ExDoc.ModuleNode{
        deprecated: nil,
        moduledoc_line: 2,
        moduledoc_file: moduledoc_file,
        docs: [function1, function2],
        docs_groups: [:Types, :Callbacks, :Functions],
        group: nil,
        id: "mod",
        language: ExDoc.Language.Erlang,
        module: :mod,
        nested_context: nil,
        nested_title: nil,
        rendered_doc: nil,
        source_path: _,
        source_url: nil,
        title: "mod",
        type: :module,
        typespecs: []
      } = mod

      assert DocAST.to_string(mod.doc) =~ "mod docs."
      assert moduledoc_file =~ "mod.erl"

      %ExDoc.FunctionNode{
        annotations: [],
        arity: 0,
        defaults: [],
        deprecated: nil,
        doc_line: 5,
        doc_file: _,
        group: :Functions,
        id: "function1/0",
        name: :function1,
        rendered_doc: nil,
        signature: _,
        source_url: nil,
        specs: _,
        type: :function
      } = function1

      assert DocAST.to_string(function1.doc) =~ "function1/0 docs."

      assert function1.doc_file =~ "mod.erl"

      assert Erlang.autolink_spec(hd(function1.specs), current_kfa: {:function, :function1, 0}) ==
               "function1() -> <a href=\"https://www.erlang.org/doc/man/erlang.html#type-atom\">atom</a>()."

      %ExDoc.FunctionNode{
        id: "function2/0"
      } = function2

      assert DocAST.to_string(function2.doc) =~ "function2/0 docs."
      assert function2.specs == []
    end

    test "module included files", c do
      erlc(c, :mod, ~S"""
      -file("module.hrl", 1).
      -module(mod).
      -file("moduledoc.hrl", 5).
      -moduledoc("mod docs.").
      -file("mod.erl",3).
      -export([function/0]).

      -file("callbackdoc.hrl", 123).
      -doc "callback foo/0 docs.".
      -file("callback.hrl", 321).
      -callback foo() -> foo().

      -file("typedoc.hrl", 234).
      -doc "type foo/0 docs.".
      -file("type.hrl", 432).
      -type foo() :: ok.

      -file("doc.hrl", 1).
      -doc("function/0 docs.").
      -file("function.hrl", 22).
      -spec function() -> atom().
      function() -> ok.
      -file("mod.erl", 8).

      """)

      {[mod], []} =
        Retriever.docs_from_modules([:mod], %ExDoc.Config{
          source_url_pattern: fn path, line ->
            path =
              Path.absname(path)
              |> Path.relative_to(c.tmp_dir)
              |> String.replace_leading("./", "")

            "#{path}:#{line}"
          end
        })

      assert %ExDoc.ModuleNode{
               deprecated: nil,
               moduledoc_line: 6,
               moduledoc_file: moduledoc_file,
               docs: [callback, function],
               docs_groups: [:Types, :Callbacks, :Functions],
               group: nil,
               id: "mod",
               language: ExDoc.Language.Erlang,
               module: :mod,
               nested_context: nil,
               nested_title: nil,
               rendered_doc: nil,
               source_path: _,
               source_url: "module.hrl:2",
               title: "mod",
               type: :behaviour,
               typespecs: [type]
             } = mod

      assert DocAST.to_string(mod.doc) =~ "mod docs."
      assert moduledoc_file =~ "moduledoc.hrl"

      assert %ExDoc.FunctionNode{
               annotations: [],
               arity: 0,
               defaults: [],
               deprecated: nil,
               doc_line: 2,
               doc_file: _,
               group: :Functions,
               id: "function/0",
               name: :function,
               rendered_doc: nil,
               signature: _,
               source_url: "function.hrl:24",
               specs: _,
               type: :function
             } = function

      assert DocAST.to_string(function.doc) =~ "function/0 docs."

      assert function.doc_file =~ "doc.hrl"

      assert %ExDoc.FunctionNode{
               id: "c:foo/0",
               doc_line: 124,
               source_url: "callback.hrl:322"
             } = callback

      assert DocAST.to_string(callback.doc) =~ "callback foo/0 docs."
      assert callback.doc_file =~ "callbackdoc.hrl"

      assert %ExDoc.TypeNode{
               id: "t:foo/0",
               doc_line: 235,
               source_url: "type.hrl:433"
             } = type

      assert DocAST.to_string(type.doc) =~ "type foo/0 docs."
      assert type.doc_file =~ "typedoc.hrl"
    end

    test "function with no docs is generated", c do
      erlc(c, :mod, ~S"""
      -module(mod).
      -export([f/0]).

      f() -> ok.
      """)

      {[mod], []} = Retriever.docs_from_modules([:mod], %ExDoc.Config{})
      assert [_] = mod.docs
    end

    test "callbacks", c do
      erlc(c, :mod, ~S"""
      -module(mod).

      -doc("callback1/0 docs.").
      -callback callback1() -> atom().

      -doc("optional_callback1/0 docs.").
      -callback optional_callback1() -> atom().

      -optional_callbacks([optional_callback1/0]).
      """)

      config = %ExDoc.Config{source_url_pattern: "%{path}:%{line}"}
      {[mod], []} = Retriever.docs_from_modules([:mod], config)
      [callback1, optional_callback1] = mod.docs

      assert callback1.id == "c:callback1/0"
      assert callback1.type == :callback
      assert callback1.annotations == []
      assert DocAST.to_string(callback1.doc) =~ "callback1/0 docs."
      assert Path.basename(callback1.source_url) == "mod.erl:4"

      assert Erlang.autolink_spec(hd(callback1.specs), current_kfa: {:callback, :callback1, 0}) ==
               "callback1() -> <a href=\"https://www.erlang.org/doc/man/erlang.html#type-atom\">atom</a>()."

      assert optional_callback1.id == "c:optional_callback1/0"
      assert optional_callback1.type == :callback
      assert optional_callback1.annotations == ["optional"]
    end

    test "types", c do
      erlc(c, :mod, ~S"""
      -module(mod).
      -export_type([type1/0, opaque1/0]).

      -doc("type1/0 docs.").
      -type type1() :: atom().

      -doc("opaque1/0 docs.").
      -opaque opaque1() :: atom().
      """)

      config = %ExDoc.Config{source_url_pattern: "%{path}:%{line}"}
      {[mod], []} = Retriever.docs_from_modules([:mod], config)
      [opaque1, type1] = mod.typespecs

      assert opaque1.id == "t:opaque1/0"
      assert opaque1.type == :opaque
      assert opaque1.signature == "opaque1()"
      assert opaque1.doc |> DocAST.to_string() =~ "opaque1/0 docs."

      assert opaque1.spec |> Erlang.autolink_spec(current_kfa: {:type, :opaque1, 0}) ==
               "opaque1()"

      assert type1.id == "t:type1/0"
      assert type1.type == :type
      assert type1.signature == "type1()"
      assert type1.doc |> DocAST.to_string() =~ "type1/0 docs."

      assert type1.spec |> Erlang.autolink_spec(current_kfa: {:type, :type1, 0}) ==
               "type1() :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-atom\">atom</a>()."
    end

    test "records", c do
      erlc(c, :mod, ~s"""
      -module(mod).
      -export([function/0]).

      -record(a, { a = 1 :: pos_integer(),
                   b :: non_neg_integer(),
                   c :: atom(),
                   d = 1,
                   e}).

      -type type() :: #a{}.
      -callback callback() -> #a{}.

      -spec function() -> type() | #a{ a :: integer(), b :: integer() }.
      function() -> ok.
      """)

      config = %ExDoc.Config{}
      {[mod], []} = Retriever.docs_from_modules([:mod], config)

      [callback, function] = mod.docs
      [type] = mod.typespecs

      assert hd(function.specs)
             |> Erlang.autolink_spec(current_module: :mod, current_kfa: {:function, :function, 0}) ==
               "function() -> <a href=\"#t:type/0\">type</a>() | #a{a :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-integer\">integer</a>(), b :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-integer\">integer</a>(), c :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-atom\">atom</a>(), d :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-term\">term</a>(), e :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-term\">term</a>()}."

      assert hd(callback.specs)
             |> Erlang.autolink_spec(current_module: :mod, current_kfa: {:callback, :callback, 0}) ==
               "callback() ->\n            #a{a :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-pos_integer\">pos_integer</a>(), b :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-non_neg_integer\">non_neg_integer</a>(), c :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-atom\">atom</a>(), d :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-term\">term</a>(), e :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-term\">term</a>()}."

      assert type.spec
             |> Erlang.autolink_spec(current_module: :mod, current_kfa: {:type, :type, 0}) ==
               "type() :: #a{a :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-pos_integer\">pos_integer</a>(), b :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-non_neg_integer\">non_neg_integer</a>(), c :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-atom\">atom</a>(), d :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-term\">term</a>(), e :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-term\">term</a>()}."
    end
  end

  describe "docs_from_modules/2 edoc" do
    @describetag :otp_eep48
    test "module", c do
      erlc(c, :mod, ~S"""
      %% @doc
      %% mod docs.
      -module(mod).
      -export([function1/0, function2/0]).

      %% @doc
      %% function1/0 docs.
      -spec function1() -> atom().
      function1() -> ok.

      %% @doc
      %% function2/0 docs.
      function2() -> ok.
      """)

      {[mod], []} = Retriever.docs_from_modules([:mod], %ExDoc.Config{})

      %ExDoc.ModuleNode{
        deprecated: nil,
        moduledoc_line: _,
        docs: [function1, function2],
        docs_groups: [:Types, :Callbacks, :Functions],
        group: nil,
        id: "mod",
        language: ExDoc.Language.Erlang,
        module: :mod,
        nested_context: nil,
        nested_title: nil,
        rendered_doc: nil,
        source_path: _,
        source_url: nil,
        title: "mod",
        type: :module,
        typespecs: []
      } = mod

      assert DocAST.to_string(mod.doc) =~ "mod docs."

      %ExDoc.FunctionNode{
        annotations: [],
        arity: 0,
        defaults: [],
        deprecated: nil,
        doc_line: _,
        doc_file: _,
        group: :Functions,
        id: "function1/0",
        name: :function1,
        rendered_doc: nil,
        signature: _,
        source_url: nil,
        specs: _,
        type: :function
      } = function1

      assert DocAST.to_string(function1.doc) =~ "function1/0 docs."

      assert Erlang.autolink_spec(hd(function1.specs), current_kfa: {:function, :function1, 0}) ==
               "function1() -> <a href=\"https://www.erlang.org/doc/man/erlang.html#type-atom\">atom</a>()."

      %ExDoc.FunctionNode{
        id: "function2/0"
      } = function2

      assert DocAST.to_string(function2.doc) =~ "function2/0 docs."
      assert function2.specs == []
    end

    test "function with no docs is generated", c do
      erlc(c, :mod, ~S"""
      %% @doc Docs.
      -module(mod).
      -export([f/0]).

      f() -> ok.
      """)

      {[mod], []} = Retriever.docs_from_modules([:mod], %ExDoc.Config{})
      assert [_] = mod.docs
    end

    test "callbacks", c do
      erlc(c, :mod, ~S"""
      %% @doc Docs.
      -module(mod).

      -callback callback1() -> atom().
      %% callback1/0 docs.

      -callback optional_callback1() -> atom().
      %% optional_callback1/0 docs.

      -optional_callbacks([optional_callback1/0]).
      """)

      config = %ExDoc.Config{source_url_pattern: "%{path}:%{line}"}
      {[mod], []} = Retriever.docs_from_modules([:mod], config)
      [callback1, optional_callback1] = mod.docs

      assert callback1.id == "c:callback1/0"
      assert callback1.type == :callback
      assert callback1.annotations == []
      assert DocAST.to_string(callback1.doc) =~ "callback1/0 docs."
      assert Path.basename(callback1.source_url) == "mod.erl:4"

      assert Erlang.autolink_spec(hd(callback1.specs), current_kfa: {:callback, :callback1, 0}) ==
               "callback1() -> <a href=\"https://www.erlang.org/doc/man/erlang.html#type-atom\">atom</a>()."

      assert optional_callback1.id == "c:optional_callback1/0"
      assert optional_callback1.type == :callback
      assert optional_callback1.annotations == ["optional"]
    end

    test "types", c do
      erlc(c, :mod, ~S"""
      %% @doc Docs.
      -module(mod).
      -export_type([type1/0, opaque1/0]).

      -type type1() :: atom().
      %% type1/0 docs.

      -opaque opaque1() :: atom().
      %% opaque1/0 docs.
      """)

      config = %ExDoc.Config{source_url_pattern: "%{path}:%{line}"}
      {[mod], []} = Retriever.docs_from_modules([:mod], config)
      [opaque1, type1] = mod.typespecs

      assert opaque1.id == "t:opaque1/0"
      assert opaque1.type == :opaque
      assert opaque1.signature == "opaque1/0"
      assert opaque1.doc |> DocAST.to_string() =~ "opaque1/0 docs."

      assert opaque1.spec |> Erlang.autolink_spec(current_kfa: {:type, :opaque1, 0}) ==
               "opaque1()"

      assert type1.id == "t:type1/0"
      assert type1.type == :type
      assert type1.signature == "type1/0"
      assert type1.doc |> DocAST.to_string() =~ "type1/0 docs."

      assert type1.spec |> Erlang.autolink_spec(current_kfa: {:type, :type1, 0}) ==
               "type1() :: <a href=\"https://www.erlang.org/doc/man/erlang.html#type-atom\">atom</a>()."
    end
  end
end
