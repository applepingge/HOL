structure disassemblerLib :> disassemblerLib =
struct

(* app load ["armTheory","coreTheory"]; *)
open HolKernel boolLib;

(* ----------------------------------------------------------------- *)

datatype shiftmode = Immediate of num |
                     Immediate_shift of {Imm : int, Rm : int, Sh : string} |
                     Register_shift of {Rm : int, Rs : int, Sh : string};

datatype iclass = swp | mrs | msr | Data_proc of shiftmode | mla_mul |
                  ldr_str | ldm_stm | br | swi_ex | cdp_und;

(* ----------------------------------------------------------------- *)

fun num2list l n =
  if l = 0 then
    []
   else if n = Arbnum.zero then
     List.tabulate(l,fn x => 0)
   else
     (if Arbnum.mod2 n = Arbnum.one then [1] else [0]) @
     (num2list (l - 1) (Arbnum.div2 n));

val numeral2num = (numSyntax.dest_numeral o snd o dest_comb);

local 
  fun llist2num [] n = n
   |  llist2num (x::xs) n = llist2num xs ((if x = 1 then Arbnum.plus1 else I) (Arbnum.times2 n))
in
  fun list2num l = llist2num (rev l) Arbnum.zero
end;

(* ----------------------------------------------------------------- *)

fun bitsl h l n = List.take(List.drop(n,l),h + 1 - l);
fun bits h l n = (Arbnum.toInt o list2num) (bitsl h l n);
fun bit b n = (bits b b n = 1);

fun Rn l = bits 19 16 l;
fun Rd l = bits 15 12 l;
fun Rs l = bits 11 8 l;
fun Rm l = bits 3 0 l;

(* ----------------------------------------------------------------- *)

fun decode_shift z l =
  case l of
    [0,0] => "LSL"
  | [0,1] => "LSR"
  | [1,0] => "ASR"
  | [1,1] => if z then "RRX" else "ROR"
  | _ => raise HOL_ERR { origin_structure = "disassemlerLib",
                         origin_function = "decode_shift",
                         message = "Can't decode shift." };

val msb32 = Arbnum.pow(Arbnum.two,Arbnum.fromInt 31);
fun smsb b = if b then msb32 else Arbnum.zero;

local
  fun mror32 x n =
    if n = 0 then
      x
    else
      (mror32 (Arbnum.+(Arbnum.div2 x, smsb (Arbnum.mod2 x = Arbnum.one)))) (n - 1);
in
  fun ror32 x n = mror32 x (n mod 32)
end;

fun decode_immediate l =
  let val rot = bits 11 8 l
      val imm = list2num (bitsl 7 0 l);
  in
    ror32 imm (2 * rot)
  end;

fun decode_immediate_shift l =
  let val imm = bits 11 7 l in
    {Rm = Rm l, Imm = imm, Sh = decode_shift (imm = 0) (bitsl 6 5 l)}
  end;

fun decode_register_shift l =
    {Rm = Rm l, Rs = Rs l, Sh = decode_shift false (bitsl 6 5 l)};

(* ----------------------------------------------------------------- *)

fun decode_inst l =
  let fun op2 x = rev (List.drop(x,16)) in
  case l of
    [0,0,1,1,0,_,1,0,_,_,_,_,1,1,1,1,_,_,_,_,_,_,_,_,_,_,_,_] => msr 
  | [0,0,0,1,0,_,1,0,_,_,_,_,1,1,1,1,0,0,0,0,0,0,0,0,_,_,_,_] => msr
  | [0,0,0,1,0,_,0,0,1,1,1,1,_,_,_,_,_,0,0,0,0,0,0,0,0,0,0,0] => mrs
  | [0,0,1,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_] => Data_proc (Immediate (decode_immediate (op2 l)))
  | [0,0,0,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,0,_,_,_,_] => Data_proc (Immediate_shift (decode_immediate_shift (op2 l)))
  | [0,0,0,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,0,_,_,1,_,_,_,_] => Data_proc (Register_shift (decode_register_shift (op2 l)))
  | [0,0,0,0,0,0,_,_,_,_,_,_,_,_,_,_,_,_,_,_,1,0,0,1,_,_,_,_] => mla_mul
  | [0,0,0,1,0,_,0,0,_,_,_,_,_,_,_,_,0,0,0,0,1,0,0,1,_,_,_,_] => swp
  | [0,1,0,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_] => ldr_str
  | [0,1,1,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,0,_,_,_,_] => ldr_str
  | [1,0,0,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_] => ldm_stm
  | [1,0,1,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_] => br
  | [1,1,1,1,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_] => swi_ex
  | _ => cdp_und
  end;

fun decode_condition l =
  case l of
    [0,0,0,0] => "EQ"
  | [0,0,0,1] => "NE"
  | [0,0,1,0] => "CS"
  | [0,0,1,1] => "CC"
  | [0,1,0,0] => "MI"
  | [0,1,0,1] => "PL"
  | [0,1,1,0] => "VS"
  | [0,1,1,1] => "VC"
  | [1,0,0,0] => "HI"
  | [1,0,0,1] => "LS"
  | [1,0,1,0] => "GE"
  | [1,0,1,1] => "LT"
  | [1,1,0,0] => "GT"
  | [1,1,0,1] => "LE"
  | [1,1,1,0] => "" (* AL *)
  | _ => "NV";

fun decode_opcode l =
  case l of
    [0,0,0,0] => "AND"
  | [0,0,0,1] => "EOR"
  | [0,0,1,0] => "SUB"
  | [0,0,1,1] => "RSB"
  | [0,1,0,0] => "ADD"
  | [0,1,0,1] => "ADC"
  | [0,1,1,0] => "SBC"
  | [0,1,1,1] => "RSC"
  | [1,0,0,0] => "TST"
  | [1,0,0,1] => "TEQ"
  | [1,0,1,0] => "CMP"
  | [1,0,1,1] => "CMN"
  | [1,1,0,0] => "ORR"
  | [1,1,0,1] => "MOV"
  | [1,1,1,0] => "BIC"
  | _ => "MVN";

fun decode_address_mode p u =
  case (p,u) of
    (false,false) => "DA"
  | (false,true)  => "IA"
  | (true,false)  => "DB"
  | (true,true)   => "IB";

fun register_string n = "r" ^ int_to_string n;

local
  fun finish i ys = if ys = [] then [(i,i)] else ((fst (hd ys), i)::(tl ys));
  fun blocks [] i ys = ys
    | blocks [x] i ys = if x then finish i ys else ys
    | blocks (x::y::xs) i ys =
    case (x,y) of
      (true,true) => blocks (y::xs) (i + 1) ys
    | (false,true) => blocks (y::xs) (i + 1) ((i + 1,~1)::ys)
    | (true,false) => blocks (y::xs) (i + 1) (finish i ys)
    | (false,false) => blocks (y::xs) (i + 1) ys;
  fun make_blocks l = let val bl = map (fn x => x = 1) l in
      rev (blocks bl 0 (if hd bl then [(0,~1)] else [])) end;
  fun blocks_to_string [] s = s ^ "}"
    | blocks_to_string ((i,j)::xs) s =
        let val comma = (if xs = [] then "" else ", ") in
          blocks_to_string xs (if i = j then s ^ register_string i ^ comma
                             else if i + 1 = j then  s ^ register_string i ^ ", " ^ register_string j ^ comma
                             else s ^ register_string i ^ "-" ^ register_string j ^ comma)
        end;
in
  fun decode_register_list l = blocks_to_string (make_blocks (List.take(l,16))) "{"
end;

(* ----------------------------------------------------------------- *)

fun decode_mode l =
  case l of
    [1,0,0,0,0] => "usr"
  | [1,0,0,0,1] => "fiq"
  | [1,0,0,1,0] => "irq"
  | [1,0,0,1,1] => "svc"
  | [1,0,1,1,1] => "abt"
  | [1,1,0,1,1] => "und"
  | [1,1,1,1,1] => "sys"
  | _ => "safe";

fun decode_psr l =
  {N = bit 31 l, Z = bit 30 l, C = bit 29 l, V = bit 28 l,
   I = bit 7 l, F = bit 6 l, mode = decode_mode (rev (bitsl 4 0 l))};

(* ----------------------------------------------------------------- *)

fun decode_branch l =
   let val sgn = bit 23 l
       val mag = bits 22 0 l
   in
     {L = bit 24 l, sign = sgn, offset = if sgn then abs (~8388608 + mag) else mag}
   end;

fun decode_data_proc l =
  let val opl = rev (bitsl 24 21 l)
      val binop = bit 0 opl andalso not (bit 1 opl)
  in
    {opcode = decode_opcode opl, S = bit 20 l, binop = binop, Rn = Rn l, Rd = Rd l}
  end;

fun decode_mrs l = {R = bit 22 l, Rd = Rd l};

fun decode_msr l = {I = bit 25 l, R = bit 22 l, Rm = Rm l};

fun decode_mla_mul l =
  {A = bit 21 l, S = bit 20 l, Rd = Rn l, Rn = Rd l, Rs = Rs l, Rm = Rm l};

fun decode_ldr_str l =
  {I = bit 25 l, P = bit 24 l, U = bit 23 l, B = bit 22 l, W = bit 21 l, L = bit 20 l,
   Rn = Rn l, Rd = Rd l, offset = bitsl 11 0 l};

fun decode_ldm_stm l =
  {P = bit 24 l, U = bit 23 l, S = bit 22 l, W = bit 21 l, L = bit 20 l,
   Rn = Rn l, list = decode_register_list l};

fun decode_swp l = {B = bit 22 l, Rn = Rn l, Rd = Rd l, Rm = Rm l};

(* ----------------------------------------------------------------- *)

fun psr_string n =
  let val dl = decode_psr (num2list 32 n) in
    (if #N dl then "N" else "~N") ^ (if #Z dl then " Z" else " ~Z") ^
    (if #C dl then " C" else " ~C") ^ (if #V dl then " V;" else " ~V;") ^
    (if #I dl then " I" else " ~I") ^ (if #F dl then " F;" else " ~F;") ^
    " " ^ #mode dl
  end;

(* ----------------------------------------------------------------- *)

fun shift_immediate_string (y:{Imm : int, Rm : int, Sh : string}) =
  register_string (#Rm y) ^
  (let val imm = #Imm y in
     if imm = 0 then
        if #Sh y = "RRX" then ", RRX" else ""
     else
       ", " ^ (#Sh y) ^ " #" ^ int_to_string imm
   end);

fun branch_string l conds =
  let val dl = decode_branch l in
    "B" ^ (if #L dl then "L" else "") ^ conds ^ (if #sign dl then " #-" else " #") ^ (int_to_string (#offset dl))
  end;

fun data_proc_string l conds x =
  let val dl = decode_data_proc l in
    (#opcode dl) ^ conds ^ (if #S dl andalso not (#binop dl) then "S" else "") ^ " " ^
      (if #binop dl then "" else register_string (#Rd dl) ^ ", ") ^
      (if #opcode dl = "MOV" orelse #opcode dl = "MVN" then "" else register_string (#Rn dl) ^ ", ") ^
      (case x of
         Immediate y => "#" ^ Arbnum.toString y
       | Immediate_shift y => shift_immediate_string y
       | Register_shift y => register_string (#Rm y) ^ ", " ^ (#Sh y) ^ " " ^ register_string (#Rs y))
  end;

fun mrs_string l conds =
  let val dl = decode_mrs l in
    "MRS" ^ conds ^ " " ^ register_string (#Rd dl) ^ ", " ^ (if #R dl then "SPSR" else "CPSR")
  end;

fun msr_string l conds =
  let val dl = decode_msr l in
    "MSR" ^ conds ^ " " ^ (if #R dl then "SPSR" else "CPSR") ^
      (if #I dl then "_f, #" ^ Arbnum.toString (decode_immediate l)
       else ", " ^ register_string (#Rm dl))
  end;

fun mla_mul_string l conds =
  let val dl = decode_mla_mul l in
    (if #A dl then "MLA" else "MUL") ^ conds ^ (if #S dl then "S" else "") ^ " " ^
       register_string (#Rd dl) ^ ", " ^ register_string (#Rm dl) ^ ", " ^ register_string (#Rs dl) ^
       (if #A dl then ", " ^ register_string (#Rn dl) else "")
  end;

fun ldr_str_string l conds =
  let val dl = decode_ldr_str l
      val offset = (if #I dl then
                      (if not (#U dl) then "-" else "") ^ shift_immediate_string (decode_immediate_shift (#offset dl))
                    else
                      (if not (#U dl) then "#-" else "#") ^ Arbnum.toString (list2num (#offset dl)))
  in
    (if #L dl then "LDR" else "STR") ^ conds ^ (if #B dl then "B " else " ") ^
      register_string (#Rd dl) ^ ", [" ^ register_string (#Rn dl) ^
      (if #P dl then ", " ^offset ^ "]" ^ (if #W dl then "!" else "")
       else "], " ^ offset)
  end;

fun ldm_stm_string l conds =
  let val dl = decode_ldm_stm l in
    (if #L dl then "LDM" else "STM") ^ conds ^ decode_address_mode (#P dl) (#U dl) ^ " " ^
       register_string (#Rn dl) ^ (if #W dl then "!, " else ", ") ^ #list dl ^
       (if #S dl then "^" else "")
  end;

fun swp_string l conds =
  let val dl = decode_swp l in
    "SWP" ^ conds ^ (if #B dl then "B " else " ") ^
       register_string (#Rd dl) ^ ", " ^ register_string (#Rm dl) ^ ", [" ^ register_string (#Rn dl) ^ "]"
  end;

fun swi_ex_string conds = "SWI" ^ conds;

(* ----------------------------------------------------------------- *)

fun opcode_string n =
  let val xl = num2list 32 n
      val l = List.take(xl,28)
      val iclass = decode_inst (rev l)
      val conds = decode_condition (rev (List.drop(xl,28)))
  in
    if iclass = cdp_und then "cdp_und"
    else case iclass of
           br          => branch_string l conds
         | mrs         => mrs_string l conds
         | msr         => msr_string l conds
         | Data_proc x => data_proc_string l conds x
         | mla_mul     => mla_mul_string l conds
         | ldr_str     => ldr_str_string l conds
         | ldm_stm     => ldm_stm_string l conds
         | swp         => swp_string l conds
         | swi_ex      => swi_ex_string conds
         | _ => raise term_pp_types.UserPP_Failed
  end;

(* ----------------------------------------------------------------- *)

val comb_prec = 20;

open Portable term_pp_types;

fun add_comment pps sl =
  (begin_block pps INCONSISTENT 2;
   add_break pps (1,0);add_string pps "(*";
   foldl (fn (s,x) => (add_break pps (1,0); add_string pps s)) () sl;
   add_break pps (1,0);add_string pps "*)";
   end_block pps);
  
fun word_print f sys (pgrav, lgrav, rgrav) d pps t =
  let val sl = f t
      val _ = if sl = [] then raise UserPP_Failed else ()
      val (t1,t2) = dest_comb t 
      fun pbegin b = add_string pps (if b then "(" else "")
      fun pend b = add_string pps (if b then ")" else "")
      fun decdepth d = if d < 0 then d else d - 1

      val add_l =
        case lgrav of
           Prec (n, _) => (n >= comb_prec)
         | _ => false
      val add_r =
        case rgrav of
          Prec (n, _) => (n > comb_prec)
        | _ => false
      val addparens = add_l orelse add_r
      val prec = Prec(comb_prec, GrammarSpecials.fnapp_special)
      val lprec = if addparens then Top else lgrav
      val rprec = if addparens then Top else rgrav
  in
     pbegin addparens;
     begin_block pps INCONSISTENT 2;
     sys (prec, lprec, prec) (decdepth d) t1;
     add_break pps (1, 0);
     sys (prec, prec, rprec) (decdepth d) t2;
     end_block pps;
     add_comment pps sl;
     pend addparens
  end handle HOL_ERR _ => raise term_pp_types.UserPP_Failed;

fun pr_psr t =
  ["CPSR: "^((psr_string o numeral2num o rhs o concl o REWRITE_CONV [armTheory.SUBST_def] o mk_comb) (t,``CPSR``))]
  handle Conv.UNCHANGED => [];

val pr_opcode = opcode_string o numeral2num;

(* - *)
fun pr_dp_psr t = pr_psr ((snd o dest_comb o (funpow 5 (fst o dest_comb))) t);

(* - *)
fun pr_pipe t =
  let val t1 = funpow 33 (fst o dest_comb) t
      val (t2,t3) = dest_comb t1
      val ireg = ["ireg: " ^ pr_opcode t3] handle HOL_ERR _ => []
      val (t4,t5) = (dest_comb o fst o dest_comb) t2
      val pipeb = ["pipeb: " ^ pr_opcode t5] handle HOL_ERR _ => []
      val pipea = ["pipea: " ^ (pr_opcode o snd o dest_comb o fst o dest_comb) t4] handle HOL_ERR _ => []
  in
     pipea @ pipeb @ ireg
  end;

(* - *)
fun pr_arm_ex t =
  let val t1 = (snd o dest_comb o fst o dest_comb) t in
    ["ireg: " ^ pr_opcode t1] handle HOL_ERR _ => []
  end;

(* - *)
fun pr_arm t = pr_psr ((snd o dest_comb) t);

fun pp_word_psr() = Parse.temp_add_user_printer (
  {Tyop = "dp", Thy = "core"}, word_print pr_dp_psr);

fun pp_word_pipe() = Parse.temp_add_user_printer (
  {Tyop = "ctrl", Thy = "core"}, word_print pr_pipe);

fun pp_word_arm_ex() = Parse.temp_add_user_printer (
  {Tyop = "state_arm_ex", Thy = "arm"}, word_print pr_arm_ex);

fun pp_word_arm() = Parse.temp_add_user_printer (
  {Tyop = "state_arm", Thy = "arm"}, word_print pr_arm);

fun npp_word_psr() = (Parse.temp_remove_user_printer {Tyop = "dp", Thy = "core"};());
fun npp_word_pipe() = (Parse.temp_remove_user_printer {Tyop = "ctrl", Thy = "core"};());
fun npp_word_arm_ex() = (Parse.temp_remove_user_printer {Tyop = "state_arm_ex", Thy = "arm"};());
fun npp_word_arm() = (Parse.temp_remove_user_printer {Tyop = "state_arm", Thy = "arm"};());

val _ = pp_word_psr();
val _ = pp_word_pipe();
val _ = pp_word_arm_ex();
val _ = pp_word_arm();

val _ = ``ARM6 (DP reg (\x. 0w) areg din alua alub dout)
        (CTRL 1w pipeaval 2w pipebval 3w iregval ointstart onewinst
           endinst obaselatch opipebll nxtic nxtis nopc1 oorst resetlatch
           onfq ooonfq oniq oooniq pipeaabt pipebabt iregabt2 dataabt2
           aregn2 mrq2 nbw nrw sctrlreg psrfb oareg mask orp oorp mul mul2
           borrow2 mshift)``;

end;
