%{
open Syntax

type elim =
  | Apply    of term * Location.t
  | Project  of [`fst | `snd] * Location.t
  | ElimBool of term binder * term * term * Location.t
  | ElimNat  of term binder * term * term binder binder * Location.t
  | ElimQ    of term binder * term binder * term binder binder binder * Location.t

let nil =
  { elims_data = Nil; elims_loc = Location.generated }

let build_elim elims = function
  | Apply (t, elims_loc) ->
     { elims_data = App (elims, t); elims_loc }
  | ElimBool (ty, tm_t, tm_f, elims_loc) ->
     { elims_data = ElimBool (elims, ty, tm_t, tm_f); elims_loc }
  | Project (dir, elims_loc) ->
     { elims_data = Project (elims, dir); elims_loc }
  | ElimNat (ty, tm_z, tm_s, elims_loc) ->
     { elims_data = ElimNat (elims, ty, tm_z, tm_s); elims_loc }
  | ElimQ (ty, tm, tm_eq, elims_loc) ->
     { elims_data = ElimQ (elims, ty, tm, tm_eq); elims_loc }
%}

%token <string> IDENT
%token <int> NATURAL
%token LPAREN LBRACE LSQBRACK
%token RPAREN RBRACE RSQBRACK
%token DOT COMMA COLON SEMICOLON EQUALS SLASH
%token ARROW ASTERISK UNDERSCORE
%token TRUE FALSE BOOL FOR REFL COH SUBST FUNEXT
%token HASH_FST HASH_SND
%token NAT ZERO SUCC
%token SAME_CLASS
%token SET
%token DEFINE AS
%token INTRODUCE USE
%token COERCE
%token BACKSLASH

%token EOF

%start<Syntax.term> whole_term
%start<[`Def of string * Syntax.term * Syntax.term] list> file

%%

file:
  | definitions=list(definition); EOF
    { definitions }

definition:
  | DEFINE; nm=IDENT; COLON; ty=term; AS; tm=term
    { `Def (nm, ty, tm) }

whole_term:
  | t=term; EOF { t }

binder:
  | x=IDENT
    { Some x }
  | UNDERSCORE
    { None }

term:
  | BACKSLASH; xs=nonempty_list(binder); ARROW; t=term
    { List.fold_right
         (fun x t -> { term_data = Lam (Scoping.bind x t)
                     ; term_loc  = Location.generated })
         xs t }
  | INTRODUCE; xs=nonempty_list(binder); COMMA; t=term
    { List.fold_right
         (fun x t -> { term_data = Lam (Scoping.bind x t)
                     ; term_loc  = Location.generated })
         xs t }
  | bs=nonempty_list(pi_binding); ARROW; tT=term
    { List.fold_right
         (fun (id, tS) tT -> { term_data = Pi (tS, Scoping.bind id tT)
                             ; term_loc  = Location.generated })
         bs tT }
  | tS=app_term; ARROW; tT=term
    { { term_data = Pi (tS, Scoping.bind None tT)
      ; term_loc  = Location.mk $startpos $endpos } }
  | t=sigma_term
    { t }

pi_binding:
  | LPAREN; b=binder; COLON; tS=term; RPAREN
    { (b, tS) }

sigma_term:
  | LPAREN; id=binder; COLON; tS=term; RPAREN; ASTERISK; tT=sigma_term
    { { term_data = Sigma (tS, Scoping.bind id tT)
      ; term_loc  = Location.mk $startpos $endpos
      } }
  | tS=app_term; ASTERISK; tT=sigma_term
    { { term_data = Sigma (tS, Scoping.bind None tT)
      ; term_loc  = Location.mk $startpos $endpos
      } }
  | t=quottype_term
    { t }

quottype_term:
  | ty=quottype_term; SLASH; r=app_term
    { { term_data = QuotType (ty, r)
      ; term_loc  = Location.mk $startpos $endpos
      } }
  | USE; t=app_term
    { t }
  | t=app_term
    { t }

app_term:
  | h=head; ts=nonempty_list(elim)
    { let h, es = h, Nil in
      { term_data = Neutral (h, List.fold_left build_elim nil ts)
      ; term_loc  = Location.mk $startpos $endpos } }
  | SUCC; t=base_term
    { { term_data = Succ t
      ; term_loc  = Location.mk $startpos $endpos } }
  | t=base_term
    { t }

base_term:
  | REFL
    { { term_data = Refl
      ; term_loc  = Location.mk $startpos $endpos } }
  | COH; LPAREN; tm_eq=term; RPAREN
    { { term_data = Coh tm_eq
      ; term_loc  = Location.mk $startpos $endpos } }
  | FUNEXT; LPAREN; x1=binder; x2=binder; xe=binder; DOT; e=term; RPAREN
    { { term_data = Funext (Scoping.bind3 x1 x2 xe e)
      ; term_loc  = Location.mk $startpos $endpos } }
  | SUBST; LPAREN; ty_s=term;
            COMMA; x=binder; DOT; ty_t=term;
            COMMA; tm_x=term;
            COMMA; tm_y=term;
            COMMA; tm_e=term;
           RPAREN
    { { term_data = Subst { ty_s; ty_t = Scoping.bind x ty_t; tm_x; tm_y; tm_e }
      ; term_loc  = Location.mk $startpos $endpos } }
  | SAME_CLASS; LPAREN; t=term; RPAREN
    { { term_data = SameClass t
      ; term_loc  = Location.mk $startpos $endpos } }
  | SET
    { { term_data = Set
      ; term_loc  = Location.mk $startpos $endpos } }
  | BOOL
    { { term_data = Bool
      ; term_loc  = Location.mk $startpos $endpos } }
  | TRUE
    { { term_data = True
      ; term_loc  = Location.mk $startpos $endpos } }
  | FALSE
    { { term_data = False
      ; term_loc  = Location.mk $startpos $endpos } }
  | NAT
    { { term_data = Nat
      ; term_loc  = Location.mk $startpos $endpos } }
  | ZERO
    { { term_data = Zero
      ; term_loc  = Location.mk $startpos $endpos } }
  | n=NATURAL
    { let term_loc = Location.mk $startpos $endpos in
      let rec build_nat n = function
         | 0 -> n
         | i -> build_nat { term_data = Succ n; term_loc } (i-1)
      in
      build_nat { term_data = Zero; term_loc } n }
  | LSQBRACK; ty1=term; EQUALS; ty2=term; RSQBRACK
    { { term_data = TyEq (ty1, ty2)
      ; term_loc  = Location.mk $startpos $endpos } }
  | LSQBRACK; tm1=term; COLON; ty1=term;
      EQUALS; tm2=term; COLON; ty2=term;
    RSQBRACK
    { { term_data = TmEq {tm1; ty1; tm2; ty2}
      ; term_loc  = Location.mk $startpos $endpos } }
  | LSQBRACK; tm1=term; EQUALS; tm2=term; COLON; ty=term;
    RSQBRACK
    { { term_data = TmEq {tm1; ty1=ty; tm2; ty2=ty}
      ; term_loc  = Location.mk $startpos $endpos } }
  | LSQBRACK; t=term; RSQBRACK
    { { term_data = QuotIntro t
      ; term_loc  = Location.mk $startpos $endpos } }
  | h=head
    { { term_data = Neutral (h, nil)
      ; term_loc  = Location.mk $startpos $endpos } }
  | LPAREN; ts=separated_list(COMMA, term); RPAREN
    { let rec build = function
        | []    -> failwith "FIXME: implement the unit type"
        | [t]   -> t
        | [s;t] -> { term_data = Pair (s,t)
                   ; term_loc  = Location.mk $startpos $endpos }
        | t::ts -> { term_data = Pair (t,build ts)
                   ; term_loc  = Location.mk $startpos $endpos }
      in build ts }

head:
  | COERCE; LPAREN; coercee=term;
             COMMA; src_type=term;
             COMMA; tgt_type=term;
             COMMA; eq_proof=term;
            RPAREN
    { { head_data = Coerce { coercee; src_type; tgt_type; eq_proof }
      ; head_loc  = Location.mk $startpos $endpos } }
  | id=IDENT
    { { head_data = Free_global id;
        head_loc  = Location.mk $startpos $endpos } }

elim:
  | t=base_term
      { Apply (t, Location.mk $startpos $endpos) }
  | FOR; x=binder; DOT; ty=term;
      LBRACE; TRUE; ARROW; tm_t=term;
   SEMICOLON; FALSE; ARROW; tm_f=term; option(SEMICOLON);
      RBRACE
      { ElimBool (Scoping.bind x ty, tm_t, tm_f, Location.mk $startpos $endpos) }
  | HASH_FST
      { Project (`fst, Location.mk $startpos $endpos) }
  | HASH_SND
      { Project (`snd, Location.mk $startpos $endpos) }
  | FOR; x=binder; DOT; ty=term;
            LBRACE; ZERO; ARROW; tm_z=term;
            SEMICOLON SUCC; n=binder; p=binder; ARROW; tm_s=term;
            option(SEMICOLON);
            RBRACE
      { ElimNat (Scoping.bind x ty, tm_z, Scoping.bind2 n p tm_s, Location.mk $startpos $endpos) }
  | FOR; x=binder; DOT; ty=term;
       LBRACE; LSQBRACK; a=binder; RSQBRACK; ARROW; tm=term;
    SEMICOLON; x1=binder; x2=binder; xr=binder; ARROW; tm_eq=term;
       option(SEMICOLON);
       RBRACE
      { ElimQ (Scoping.bind x ty, Scoping.bind a tm, Scoping.bind3 x1 x2 xr tm_eq, Location.mk $startpos $endpos) }