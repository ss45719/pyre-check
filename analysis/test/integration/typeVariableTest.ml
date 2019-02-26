(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)

open OUnit2
open IntegrationTest


let test_check_unbounded_variables _ =
  assert_type_errors
    {|
      T = typing.TypeVar('T')
      def expects_any(input) -> None: ...
      def expects_string(inut: str) -> None: ...
      def foo(input: T) -> None:
        expects_any(input)
        expects_string(input)
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `str` for 1st anonymous parameter to call `expects_string` but got `Variable[T]`."];
  assert_type_errors
    {|
      T = typing.TypeVar('T')
      def foo(input: T) -> typing.Any:
        return input
    |}
    ["Missing return annotation [3]: Returning `Variable[T]` but type `Any` is specified."];
  assert_type_errors
    {|
      T = typing.TypeVar('T')
      def foo(input: T) -> int:
        return input
    |}
    ["Incompatible return type [7]: Expected `int` but got `Variable[T]`."]


let test_check_variable_bindings _ =
  assert_type_errors
    {|
      T = typing.TypeVar('T', bound=int)
      def foo(t: T) -> None:
        str_to_int(t)
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `str` for 1st anonymous parameter to call `str_to_int` but got " ^
     "`Variable[T (bound to int)]`."];
  assert_type_errors
    {|
      T = typing.TypeVar('T', bound=int)
      def foo() -> T:
        return 1.0
    |}
    [
      "Invalid type variable [34]: The type variable `Variable[T (bound to int)]` isn't present \
       in the function's parameters.";
    ];
  assert_type_errors
    {|
      T = typing.TypeVar('T', bound=int)
      def foo(t: T) -> None:
        int_to_str(t)
      def bar(x: str) -> None:
        foo(x)
    |}
    ["Incompatible parameter type [6]: Expected `Variable[T (bound to int)]` for 1st anonymous " ^
     "parameter to call `foo` but got `str`."];
  assert_type_errors
    {|
      class C():
        def baz(self) -> int:
          return 7
      T = typing.TypeVar('T', bound=C)
      def foo(t: T) -> int:
        return t.baz()
    |}
    [];
  assert_type_errors
    {|
      from typing import TypeVar

      T = TypeVar("T", bound=int)

      def f(x: T, y: int) -> T:
        return x

      def buggy(n: None) -> None:
        return f(2, n)
    |}
    [
      "Incompatible return type [7]: Expected `None` but got `int`.";
      "Incompatible parameter type [6]: Expected `int` for 2nd anonymous parameter to call \
       `f` but got `None`.";
    ]


let test_bottom_unbound_variables _ =
  assert_type_errors
    {|
      T_Explicit = typing.TypeVar("T_Explicit", int, str)
      class G(typing.Generic[T_Explicit]):
        def __init__(self) -> None:
          pass
        def eat(self, x: T_Explicit) -> None:
          pass
      def bar() -> G[int]:
        g = G()
        reveal_type(g)
        g.eat(7)
        reveal_type(g)
        return g
    |}
    [
      "Revealed type [-1]: Revealed type for `g` is `G[]`.";
      "Revealed type [-1]: Revealed type for `g` is `G[int]`.";
    ]


let test_distinguish _ =
  assert_type_errors
    {|
      _T1 = typing.TypeVar("_T1")
      _T2 = typing.TypeVar("_T2")
      class C(typing.Generic[_T1]):
        def pair(self, a: _T1, b: _T2) -> typing.Tuple[_T1, _T2]:
          return (a, b)
      def foo(q: C[_T2], x: _T2, y:_T1) -> typing.Tuple[_T2, _T1]:
        A = q.pair(x, y)
        reveal_type(A)
        return A
    |}
    [
      "Revealed type [-1]: Revealed type for `A` is `typing.Tuple[Variable[_T2], Variable[_T1]]`.";
    ];
  assert_type_errors
    {|
      _T1 = typing.TypeVar("_T1")
      _T2 = typing.TypeVar("_T2")
      def foo(f: typing.Callable[[_T1], _T2], p: _T1) -> _T2:
        v = f(p)
        reveal_type(v)
        return v
    |}
    [
      "Revealed type [-1]: Revealed type for `v` is `Variable[_T2]`.";
    ];
  assert_type_errors
    {|
      _T1 = typing.TypeVar("_T1")
      _T2 = typing.TypeVar("_T2")
      def foo(f: typing.Callable[[_T1], _T2], p: _T1) -> _T2:
        return f(1)
    |}
    [
      "Incompatible parameter type [6]: Expected `Variable[_T1]` for 1st anonymous parameter to " ^
      "anoynmous call but got `int`.";
    ];
  assert_type_errors
    {|
      _T1 = typing.TypeVar("_T1")
      _T2 = typing.TypeVar("_T2")
      class B: pass
      class C(B): pass
      def foo(f: typing.Callable[[typing.List[typing.Tuple[_T1, B]]], _T2], p: _T1) -> _T2:
        v = f([(p, C())])
        reveal_type(v)
        return v
    |}
    [
      "Revealed type [-1]: Revealed type for `v` is `Variable[_T2]`.";
    ];
  ()



let () =
  "typeVariable">:::[
    "check_unbounded_variables">::test_check_unbounded_variables;
    "check_variable_bindings">::test_check_variable_bindings;
    "bottom_unbound_variables">::test_bottom_unbound_variables;
    "distinguish">::test_distinguish;
  ]
  |> Test.run
