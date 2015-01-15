open HolKernel Parse boolLib bossLib;
open EmitML

open basis_emitTheory

val _ = new_theory "emitrecord";

val fooq = `foo = <| n : num ; b : bool |>`;
val _ = Datatype fooq

val literal_def = Define`literal m = <| n := m ; b := T |>`;

val accessor_def = Define`accessor x = x.n + 1`;

val _ = eSML "emitRecordTest"
             [OPEN ["num"],
              MLSIG "type num = numML.num",
              DATATYPE fooq,
              DEFN literal_def,
              DEFN accessor_def]

val _ = export_theory();
