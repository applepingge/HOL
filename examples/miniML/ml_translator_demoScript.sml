open HolKernel Parse boolLib bossLib; val _ = new_theory "ml_translator_demo";

open ml_translatorLib ml_translatorTheory;

open arithmeticTheory listTheory combinTheory pairTheory;
open stringTheory;

infix \\ val op \\ = op THEN;


(* ************************************************************************** *

   Notes

   Partial definitions, e.g. HD, TL and ZIP, cannot be translated.

 * ************************************************************************** *)


(* examples from library *)

val res = translate MAP;
val res = translate FILTER;
val res = translate APPEND;
val res = translate REVERSE_DEF;
val res = translate LENGTH;
val res = translate FOLDR;
val res = translate FOLDL;
val res = translate sortingTheory.PART_DEF;
val res = translate sortingTheory.PARTITION_DEF;
val res = translate sortingTheory.QSORT_DEF;
val res = translate SUM;
val res = translate FST;
val res = translate SND;
val res = translate UNZIP;
val res = translate FLAT;
val res = translate TAKE_def;
val res = translate SNOC;
val res = translate REV_DEF;
val res = translate EVERY_DEF;
val res = translate EXISTS_DEF;
val res = translate GENLIST;
val res = translate o_DEF;
val res = translate K_DEF;
val res = translate W_DEF;
val res = translate C_DEF;
val res = translate S_DEF;
val res = translate I_DEF;
val res = translate FAIL_DEF;
val res = translate PAD_RIGHT;
val res = translate PAD_LEFT;
val res = translate MEM;
val res = translate ALL_DISTINCT;
val res = translate isPREFIX;


(* some locally defined examples *)

val (def,res) = mlDefine `
  (fac 0 = 1) /\
  (fac (SUC n) = SUC n * fac n)`;

val (def,res) = mlDefine `
  gcd m n = if n = 0 then m else gcd n (m MOD n)`

val (def,res) = mlDefine `
  foo f x = f (f x (\x. x))`

val (def,res) = mlDefine `
  n_times n f x = if n = 0 then x else n_times (n-1) f (f x)`

val (def,res) = mlDefine `
  fac_gcd k m n = if k = 0 then k else fac_gcd (k-1) (fac (gcd m n)) n`

val (def,res) = mlDefine `
  nlist n = if n = 0 then [] else n :: nlist (n-1)`;

val (def,res) = mlDefine `
  rhs n = if n = 0 then INR n else INL n`;

val (def,res) = mlDefine `
  rhs_option n = if n = 0 then INL NONE else INR (SOME n)`;

val (def,res) = mlDefine `
  add ((x1,x2),(y1,y2)) = x1+x2+y1+y2:num`;

val (def,res) = mlDefine `
  (silly (x,INL y) = x + y) /\
  (silly (x,INR y) = x + y:num)`;

val (def,res) = mlDefine `
  (list_test1 [] = []) /\
  (list_test1 [x] = [x]) /\
  (list_test1 (x::y::xs) = x :: list_test1 xs)`;

val (def,res) = mlDefine `
  (list_test2 [] ys = []) /\
  (list_test2 [x] ys = [(x,x)]) /\
  (list_test2 (x::y::xs) (z1::z2::ys) = (x,z1) :: list_test2 xs ys) /\
  (list_test2 _ _ = [])`;

val (def,res) = mlDefine `
  (list_test3 [] ys = 0) /\
  (list_test3 (1::xs) ys = 1) /\
  (list_test3 (2::xs) ys = 2 + list_test3 xs ys) /\
  (list_test3 _ ys = LENGTH ys)`;


(* chars, finite_maps, sets and lazy lists... *)

(* teaching the translator about characters (represented as num) *)

val CHAR_def = Define `
  CHAR (c:char) = NUM (ORD c)`;

val _ = add_type_inv ``CHAR``

val EqualityType_CHAR = prove(
  ``EqualityType CHAR``,
  EVAL_TAC \\ SRW_TAC [] [] \\ EVAL_TAC)
  |> store_eq_thm;

val Eval_Val_CHAR = prove(
  ``n < 256 ==> Eval env (Val (Lit (Num n))) (CHAR (CHR n))``,
  SIMP_TAC (srw_ss()) [Eval_Val_NUM,CHAR_def])
  |> store_eval_thm;

val Eval_ORD = prove(
  ``!v. ((NUM --> NUM) (\x.x)) v ==> ((CHAR --> NUM) ORD) v``,
  SIMP_TAC std_ss [Arrow_def,AppReturns_def,CHAR_def])
  |> MATCH_MP (MATCH_MP Eval_WEAKEN (hol2deep ``\x.x:num``))
  |> store_eval_thm;

val Eval_CHR = prove(
  ``!v. ((NUM --> NUM) (\n. n MOD 256)) v ==>
        ((NUM --> CHAR) (\n. CHR (n MOD 256))) v``,
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,CHAR_def])
  |> MATCH_MP (MATCH_MP Eval_WEAKEN (hol2deep ``\n. n MOD 256``))
  |> store_eval_thm;

val Eval_CHAR_LT = prove(
  ``!v. ((NUM --> NUM --> BOOL) (\m n. m < n)) v ==>
        ((CHAR --> CHAR --> BOOL) char_lt) v``,
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,CHAR_def,char_lt_def]
  \\ METIS_TAC [])
  |> MATCH_MP (MATCH_MP Eval_WEAKEN (hol2deep ``\m n. m < n:num``))
  |> store_eval_thm;

(* now we can translate e.g. less-than over strings *)

val res = translate string_lt_def

val (def,res) = mlDefine `
  hi n = if n = 0 then "!" else "hello " ++ hi (n-1)`


val _ = export_theory();
