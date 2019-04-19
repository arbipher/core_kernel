open! Core_kernel
open! Expect_test_helpers_kernel
open! Percent

let%test_module "Percent.V1" =
  (module Stable_unit_test.Make (struct
       include Stable.V1

       let equal = equal

       let tests =
         [ of_mult 0.375, "37.5%", "\000\000\000\000\000\000\216?"
         ; of_mult 4.5, "4.5x", "\000\000\000\000\000\000\018@"
         ; of_mult 0.0002, "2bp", "-C\028\235\2266*?"
         ; of_mult 0.000075, "0.75bp", "a2U0*\169\019?"
         ]
       ;;
     end))
;;

let%expect_test "rounding" =
  let p = Percent.of_string "0.0123456%" in
  let tests =
    [ Percent.round_significant p ~significant_digits:4
    ; Percent.round_decimal_mult p ~decimal_digits:4
    ; Percent.round_decimal_percentage p ~decimal_digits:4
    ; Percent.round_decimal_bp p ~decimal_digits:4
    ]
  in
  printf !"%{sexp:Percent.t list}" tests;
  [%expect "(1.235bp 1bp 1.23bp 1.2346bp)"]
;;

let%test_unit {|
    BUG: The sexp functions don't roundtrip.

    In this case problem is [of_percentage] divides by 100, and [of_string]
    scales by 0.01, which can yield different results.
  |}
  =
  let module V1 = Stable.V1 in
  let t = of_percentage 3.638 in
  [%test_result: int] (compare t (V1.t_of_sexp (V1.sexp_of_t t))) ~expect:(-1)
;;

let%test_unit _ =
  (* [t_of_sexp] *)
  List.iter
    ~f:(fun (string, expected) ->
      assert (equal (t_of_sexp (Sexp.Atom string)) (of_mult expected)))
    [ "30%", 0.3
    ; "3123bp", 0.3123
    ; "3.17x", 3.17
    ; "0.0003x", 0.0003
    ; "0%", 0.
    ; "0bp", 0.
    ; "0x", 0.
    ; "0.000%", 0.
    ; "0.00bp", 0.
    ; "0.00x", 0.
    ; "3.1e5%", 3100.
    ; "3.1e5bp", 31.
    ; "3.1e5x", 310000.
    ; "10%", 0.1
    ; "110%", 1.1
    ; "0.1x", 0.1
    ; "1.1x", 1.1
    ; "0.001x", 0.001
    ; "1bp", 0.0001
    ; "10bp", 0.001
    ; "100bp", 0.01
    ; "1000bp", 0.1
    ; "11000bp", 1.1
    ; "1.1e4bp", 1.1
    ; "50%", 0.5
    ]
;;

let%test_unit _ =
  (* [sexp_of_t] and [t_of_sexp] *)
  List.iter
    ~f:(fun (t1, expected) ->
      let t1 = of_mult t1 in
      let s = Sexp.to_string (sexp_of_t t1) in
      assert (String.equal s expected);
      let t2 = t_of_sexp (Sexp.of_string s) in
      assert (equal t1 t2))
    [ 0.3, "30%"
    ; 0.335, "33.5%"
    ; 0.00335, "33.5bp"
    ; 33.46, "33.46x"
    ; 0.1, "10%"
    ; 0.99, "99%"
    ; 1., "1x"
    ; 10., "10x"
    ; 0.001, "10bp"
    ; 0.0001, "1bp"
    ; 0.00001, "0.1bp"
    ; 0.5, "50%"
    ]
;;

let%test_unit _ =
  (* [to_string'] and [to_string_f] *)
  List.iter
    ~f:(fun (t, precision, format', expect, expectf) ->
      let t = of_mult t in
      let output' = format t (Format.compact_E ~precision) in
      assert (String.equal output' expect);
      let outputf = format t format' in
      assert (String.equal outputf expectf))
    [ 0.3, 3, Format.decimal ~precision:3, "30%", "30.000%"
    ; 0.333, 4, Format.decimal ~precision:2, "33.3%", "33.30%"
    ; 0.333333, 4, Format.decimal ~precision:2, "33.33%", "33.33%"
    ; 0.000333, 2, Format.decimal ~precision:2, "3.3bp", "3.33bp"
    ]
;;

let%expect_test _ =
  print_and_check_comparable_sexps
    [%here]
    (module Percent)
    [ Percent.zero; Percent.of_bp 15.; Percent.of_percentage 15.; Percent.of_mult 15. ];
  [%expect
    {|
    (Set (0x 15bp 15% 15x))
    (Map (
      (0x   0)
      (15bp 1)
      (15%  2)
      (15x  3))) |}]
;;

let%expect_test "accept float in set and map sexps" =
  let module Of_string (M : Sexpable.S1) = struct
    type t = string M.t [@@deriving sexp]
  end
  in
  let test (module M : Sexpable) string =
    print_s (M.sexp_of_t (M.t_of_sexp (Sexp.of_string string)))
  in
  test (module Percent.Set) {| (0 0.0001 0.01 1) |};
  [%expect {| (0x 1bp 1% 1x) |}];
  test
    (module Of_string (Percent.Map))
    {|
    ((0      "arbitrary value")
     (0.0001 "arbitrary value")
     (0.01   "arbitrary value")
     (1      "arbitrary value")) |};
  [%expect
    {|
    ((0x  "arbitrary value")
     (1bp "arbitrary value")
     (1%  "arbitrary value")
     (1x  "arbitrary value")) |}]
;;
