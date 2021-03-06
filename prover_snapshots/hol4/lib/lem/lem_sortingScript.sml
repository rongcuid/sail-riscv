(*Generated by Lem from sorting.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_boolTheory lem_basic_classesTheory lem_maybeTheory lem_listTheory lem_numTheory sortingTheory permLib;

val _ = numLib.prefer_num();



val _ = new_theory "lem_sorting"



(*open import Bool Basic_classes Maybe List Num*)

(*open import {isabelle} `HOL-Library.Permutation`*)
(*open import {coq} `Coq.Lists.List`*)
(*open import {hol} `sortingTheory` `permLib`*)
(*open import {isabelle} `$LIB_DIR/Lem`*)

(* ------------------------- *)
(* permutations              *)
(* ------------------------- *)

(*val isPermutation : forall 'a. Eq 'a => list 'a -> list 'a -> bool*)
(*val isPermutationBy : forall 'a. ('a -> 'a -> bool) -> list 'a -> list 'a -> bool*)

 val _ = Define `
 ((PERM_BY:('a -> 'a -> bool) -> 'a list -> 'a list -> bool) eq ([]) l2=  (NULL l2))
/\ ((PERM_BY:('a -> 'a -> bool) -> 'a list -> 'a list -> bool) eq (x :: xs) l2=  ((
      (case list_delete_first (eq x) l2 of
          NONE => F
        | SOME ys => PERM_BY eq xs ys
      )
    )))`;




(* ------------------------- *)
(* isSorted                  *)
(* ------------------------- *)

(* isSortedBy R l 
   checks, whether the list l is sorted by ordering R. 
   R should represent an order, i.e. it should be transitive.
   Different backends defined "isSorted" slightly differently. However,
   the definitions coincide for transitive R. Therefore there is the
   following restriction:

   WARNING: Use isSorted and isSortedBy only with transitive relations!
*)

(*val isSorted : forall 'a. Ord 'a => list 'a -> bool*)
(*val isSortedBy : forall 'a. ('a -> 'a -> bool) -> list 'a -> bool*)

(* DPM: rejigged the definition with a nested match to get past Coq's termination checker. *)
(*let rec isSortedBy cmp l=  match l with
  | [] -> true
  | x1 :: xs ->
    match xs with
      | [] -> true
      | x2 :: _ -> (cmp x1 x2 && isSortedBy cmp xs)
    end
end*)


(* ----------------------- *)
(* insertion sort          *)
(* ----------------------- *) 

(*val insert : forall 'a. Ord 'a => 'a -> list 'a -> list 'a*)
(*val insertBy : forall 'a. ('a -> 'a -> bool) -> 'a -> list 'a -> list 'a*)

(*val insertSort: forall 'a. Ord 'a => list 'a -> list 'a*)
(*val insertSortBy: forall 'a. ('a -> 'a -> bool) -> list 'a -> list 'a*)

 val _ = Define `
 ((INSERT_SORT_INSERT:('a -> 'a -> bool) -> 'a -> 'a list -> 'a list) cmp e ([])=  ([e]))
/\ ((INSERT_SORT_INSERT:('a -> 'a -> bool) -> 'a -> 'a list -> 'a list) cmp e (x :: xs)=  (if cmp x e then x :: (INSERT_SORT_INSERT cmp e xs) else (e :: (x :: xs))))`;


val _ = Define `
 ((INSERT_SORT:('a -> 'a -> bool) -> 'a list -> 'a list) cmp l=  (FOLDL (\ l e .  INSERT_SORT_INSERT cmp e l) [] l))`;



(* ----------------------- *)
(* general sorting         *)
(* ----------------------- *) 

(*val sort: forall 'a. Ord 'a => list 'a -> list 'a*)
(*val sortBy: forall 'a. ('a -> 'a -> bool) -> list 'a -> list 'a*)
(*val sortByOrd: forall 'a. ('a -> 'a -> ordering) -> list 'a -> list 'a*)

(*val predicate_of_ord : forall 'a. ('a -> 'a -> ordering) -> 'a -> 'a -> bool*)
val _ = Define `
 ((predicate_of_ord:('a -> 'a -> ordering) -> 'a -> 'a -> bool) f x y=
   ((case f x y of
      LESS => T
    | EQUAL => T
    | GREATER => F
  )))`;



val _ = export_theory()

