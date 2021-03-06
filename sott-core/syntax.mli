type 'a binder =
  | B  of string * 'a

type term =
  { term_loc  : Location.t
  ; term_data : term_data
  }

and term_data =
  | Neutral of head * elims

  | Set

  | Pi of term * term binder
  | Lam of term binder

  | QuotType  of term * term
  | QuotIntro of term

  | Sigma of term * term binder
  | Pair of term * term

  | Bool
  | True
  | False

  | Nat
  | Zero
  | Succ of term

  | TyEq of term * term
  | TmEq of { tm1 : term; ty1 : term; tm2 : term; ty2 : term }

  (* proof constructors *)
  | Subst of { ty_s : term
             ; ty_t : term binder
             ; tm_x : term
             ; tm_y : term
             ; tm_e : term
             }
  | Refl
  | Coh of term
  | Funext of term binder binder binder
  | SameClass of term

  (* placeholder for an erased proof term; only generated during
     reification. *)
  | Irrel

and head =
  { head_loc  : Location.t
  ; head_data : head_data
  }

and head_data =
  | Bound  of int
  | Free_local of string
  | Free_global of string
  | Coerce of { coercee  : term
              ; src_type : term
              ; tgt_type : term
              ; eq_proof : term
              }

and elims =
  { elims_loc  : Location.t
  ; elims_data : elims_data
  }

and elims_data =
  | Nil
  | App      of elims * term
  | Project  of elims * [`fst | `snd]
  | ElimBool of elims * term binder * term * term
  | ElimNat  of elims * term binder * term * term binder binder
  | ElimQ    of elims * term binder * term binder * term binder binder binder


val alpha_eq : term -> term -> bool

module type EXTENDABLE_CONTEXT = sig
  type t

  type ty

  type tm

  val extend : string -> ty -> t -> string * t

  val mk_free : string -> ty -> tm
end

module Scoping : sig
  val bind : string option -> term -> term binder

  val bind2 : string option -> string option -> term -> term binder binder

  val bind3 : string option -> string option -> string option -> term -> term binder binder binder

  module Close (Ctxt : EXTENDABLE_CONTEXT) : sig
    val close :
      Ctxt.ty ->
      term binder ->
      Ctxt.t ->
      Ctxt.tm * term * Ctxt.t

    val close2 :
      Ctxt.ty ->
      (Ctxt.tm -> Ctxt.ty) ->
      term binder binder ->
      Ctxt.t ->
      Ctxt.tm * Ctxt.tm * term * Ctxt.t

    val close3 :
      Ctxt.ty ->
      (Ctxt.tm -> Ctxt.ty) ->
      (Ctxt.tm -> Ctxt.tm -> Ctxt.ty) ->
      term binder binder binder ->
      Ctxt.t ->
      Ctxt.tm * Ctxt.tm * Ctxt.tm * term * Ctxt.t
  end
end

(** Internal representation of checked terms *)
type value

val reify_type : value -> int -> term

module Context : sig
  type t

  val empty : t

  val extend_with_defn : string -> ty:value -> tm:value -> t -> t

  val lookup_exn : string -> t -> value * value option

  val local_bindings : t -> (string * value) list
end

module Evaluation : sig
  val eval0 : Context.t -> term -> value
end

type error_message =
  | Type_mismatch of { loc : Location.t; ctxt : Context.t; computed_ty : term; expected_ty : term }
  | Types_not_equal of { loc : Location.t; ctxt : Context.t; ty1 : term; ty2 : term }
  | Term_is_not_a_type of Location.t
  | Term_mismatch of Location.t * Context.t * term * term * term
  | VarNotFound of Location.t * string
  | BadApplication of { loc : Location.t; arg_loc : Location.t; ctxt : Context.t; ty : term }
  | MsgLoc of Location.t * string

val is_type : Context.t -> term -> (unit, error_message) result

val has_type : Context.t -> value -> term -> (unit, error_message) result
