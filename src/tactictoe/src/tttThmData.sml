(* ========================================================================== *)
(* FILE          : tttThmData.sml                                             *)
(* DESCRIPTION   :                                                            *)
(*                                                                            *)
(* AUTHOR        : (c) Thibault Gauthier, University of Innsbruck             *)
(* DATE          : 2017                                                       *)
(* ========================================================================== *)

structure tttThmData :> tttThmData =
struct

open HolKernel boolLib Abbrev tttTools tttExec tttLexer tttFeature tttPredict
tttSetup

val ERR = mk_HOL_ERR "tttThmData"

(* --------------------------------------------------------------------------
   Import
   -------------------------------------------------------------------------- *)

fun thm_of_string s =
  let val (a,b) = split_string "Theory." s in DB.fetch a b end

fun parse_thmfea s = case ttt_lex s of
    a :: m => (SOME (dest_thm (thm_of_string a), (a, map string_to_int m))
      handle _ => NONE)
  | _ => raise ERR "parse_thmfea" s

fun read_thmfea thy =
  let
    val l0 = readl (ttt_thmfea_dir ^ "/" ^ thy)
      handle _ => (if mem thy ["min"] 
                   then []
                   else (
                        print_endline (thy ^ " theorems missing;"); 
                        debug (thy ^ " theorems missing;"); 
                        []
                        )
                  )
    val l1 = List.mapPartial parse_thmfea l0
  in
    ttt_thmfea := daddl l1 (!ttt_thmfea)
  end

fun import_thmfea thyl = app read_thmfea thyl

(* --------------------------------------------------------------------------
   Update
   -------------------------------------------------------------------------- *)

fun update_thmfea cthy =
  let
    val thml = DB.thms cthy
    fun f (s,thm) =
      let
        val name = cthy ^ "Theory." ^ s
        val goal = dest_thm thm
        val fea = snd (dfind goal (!ttt_thmfea))
          handle _ => fea_of_goal goal
      in
        ttt_thmfea := dadd goal (name,fea) (!ttt_thmfea)
      end
  in
    app f thml
  end

(* --------------------------------------------------------------------------
   Export
   -------------------------------------------------------------------------- *)

fun export_thmfea cthy =
  let
    val cthy_suffix = cthy ^ ttt_new_theory_suffix
    val _ = if cthy = "bool" 
            then update_thmfea "bool"
            else update_thmfea cthy_suffix
    val namel = 
      if cthy = "bool" 
      then map fst (DB.thms "bool")
      else map fst (DB.thms (cthy_suffix))
    fun in_curthy (_,(s,_)) =
      let val (thy,name) = split_string "Theory." s in
        (thy = cthy_suffix orelse thy = cthy) andalso mem name namel
      end
    val fname = ttt_thmfea_dir ^ "/" ^ cthy
    val l0 = filter in_curthy (dlist (!ttt_thmfea))
    fun f (_,(name,fea)) =
      String.concatWith " " 
        (remove_string ttt_new_theory_suffix name :: map int_to_string fea)
    val l1 = map f l0
  in
    writel fname l1
  end

end (* struct *)