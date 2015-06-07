open Types

exception EvalError of string

let print_process msg =
  (*
    print_string (msg ^ "\n") ;
  *)
  ()

let rec string_of_ast ast =
  match ast with
  | LambdaAbstract(x, m) -> "(Lam: " ^ x ^ ". " ^ (string_of_ast m) ^ ")"
  | FuncWithEnvironment(x, m, _) -> "(LamEnv: " ^ x ^ ". " ^ (string_of_ast m) ^ ")"
  | ContentOf(v) -> "(" ^ v ^ ")"
  | NumericApply(m, n) -> "($ " ^ (string_of_ast m) ^ " " ^ (string_of_ast n) ^ ")"
  | Concat(s, t) -> (string_of_ast s) ^ "-" ^ (string_of_ast t)
  | StringEmpty -> "!"
  | _ -> "_"

let rec make_argument_cons lst =
  match lst with
  | [] -> EndOfArgumentVariable
  | head :: tail -> ArgumentVariableCons(head, make_argument_cons tail)
(* abstract_tree -> abstract_tree *)

let copy_environment env = Hashtbl.copy env

let add_to_environment env varnm rfast =
  ( print_process ("  add " ^ varnm ^ " := " ^ (string_of_ast !rfast)) ;
    Hashtbl.add env varnm rfast
  )

let rec main ast_main =
  let loc_same : location = ref NoContent in
  let loc_deeper : location = ref NoContent in
  let loc_break : location = ref NoContent in
  let loc_include : location = ref NoContent in
  let env_main : environment = Hashtbl.create 128 in
    add_to_environment env_main "same" loc_same ;
    add_to_environment env_main "\\deeper" loc_deeper ;
    add_to_environment env_main "\\break" loc_break ;
    add_to_environment env_main "\\include" loc_include ;
    loc_same := FuncWithEnvironment("~stra", 
                  FuncWithEnvironment("~strb",
                    PrimitiveSame(ContentOf("~stra"), ContentOf("~strb")),
                    env_main
                  ),
                  env_main
                ) ;
    loc_deeper := FuncWithEnvironment("~content",
                    Concat(DeeperIndent(Concat(BreakAndIndent, ContentOf("~content"))), BreakAndIndent),
                    env_main
                  ) ;
    loc_break  := BreakAndIndent ;

    loc_include  := FuncWithEnvironment("~filename",
                      PrimitiveInclude(ContentOf("~filename")),
                      env_main
                    ) ;
    interpret env_main ast_main

(* (macro_environment ref) -> int -> (var_environment ref) -> abstract_tree -> abstract_tree *)
and interpret env ast =
  match ast with
  | StringEmpty -> StringEmpty

  | NoContent -> NoContent

  | ConcatOperation(astf, astl) -> interpret env (Concat(astf, astl))

  | Concat(astf, astl) ->
      let valuef = interpret env astf in
      let valuel = interpret env astl in
      ( match (valuef, valuel) with
        | (StringEmpty, _) -> valuel
        | (_, StringEmpty) -> valuef
        | (_, _) -> Concat(valuef, valuel)
      )

  | StringConstant(c) -> StringConstant(c)

  | ContentOf(v) ->
    ( print_process (">ContentOf: " ^ v) ;
      ( try
          let content = !(Hashtbl.find env v) in
          ( print_process ("  -> " ^ (string_of_ast content)) ;
            content )
        with
        | Not_found -> raise (EvalError("undefined variable '" ^ v ^ "'"))
      )
    )
  | Separated(astf, astl) ->
      let valuef = interpret env astf in
      let valuel = interpret env astl in
        Separated(valuef, valuel)

  | LetIn(nv, astdef, astrest) ->
    ( print_process (">LetIn: " ^ nv ^ " / "
        ^ (string_of_ast astdef) ^ " / " ^ (string_of_ast astrest)) ;
      let env_func = copy_environment env in
      ( (* add_to_environment env_func nv (ref NoContent) ; *)
        let valuedef =
        ( let intprtd = interpret env_func astdef in
            match intprtd with
            | LambdaAbstract(varnm, ast) -> FuncWithEnvironment(varnm, ast, env_func)
            | other -> other
        )
        in
        ( add_to_environment env_func nv (ref valuedef) (* overwrite nv *) ;
          interpret env_func astrest
        )
      )
    )
  | LambdaAbstract(varnm, ast) -> (
      print_process (">LambdaAbstract: " ^ varnm ^ ". " ^ (string_of_ast ast))  ;
      FuncWithEnvironment(varnm, ast, env)
    )
  | FuncWithEnvironment(varnm, ast, env) -> (
      print_process ">FuncWithEnvironment" ;
      FuncWithEnvironment(varnm, ast, env)
    )

  | NumericApply(astf, astl) ->
    ( print_process ">NumericApply" ;
      print_process ("  " ^ (string_of_ast astf) ^ " / " ^ (string_of_ast astl)) ;
      let valuel = interpret env astl in
      let fspec = interpret env astf in
      ( print_process ("  => " ^ (string_of_ast fspec) ^ " / " ^ (string_of_ast valuel)) ;
      ( match fspec with
        | FuncWithEnvironment(varnm, astdef, envf) ->
            let env_new = copy_environment envf in
            ( add_to_environment env_new varnm (ref valuel) ;
              let intpd = interpret env_new astdef in ( print_process ("  end " ^ varnm) ; intpd )
            )
        | LambdaAbstract(varnm, astdef) ->
            let env_new = copy_environment env in
            ( add_to_environment env_new varnm (ref valuel) ;
              interpret env_new astdef
            )
        | _ -> raise (EvalError("illegal apply"))
      )
      )
    )
(*
  | StringApply(f, clsnmarg, idnmarg, argcons) ->
    ( try
        let fspec = !(Hashtbl.find env f) in
          match fspec with
          | FuncWithEnvironment(argvarcons, astf, envf) ->
              let env_new = copy_environment envf in
              ( ( match clsnmarg with
                  | NoClassName -> add_to_environment env_new "@class" (ref NoContent)
                  | ClassName(clsnm) -> add_to_environment env_new "@class" (ref (class_name_to_abstract_tree clsnm))
                ) ;
                ( match idnmarg with
                  | NoIDName -> add_to_environment env_new "@id" (ref NoContent)
                  | IDName(idnm) -> add_to_environment env_new "@id" (ref (id_name_to_abstract_tree idnm))
                ) ;
                deal_with_cons env_new argvarcons argcons ;
                let valuef = interpret env_new astf in
                ( Hashtbl.clear env_new ;
                  valuef
                )
              )
          | _ -> raise (EvalError("illegal apply of control sequence '" ^ f ^ "'"))
      with
      | Not_found -> raise (EvalError("undefined control sequence '" ^ f ^ "'"))
    )
*)
  | DeeperIndent(abstr) -> let res = interpret env abstr in DeeperIndent(res)

  | BreakAndIndent -> BreakAndIndent

  | PrimitiveSame(ast1, ast2) ->
      let str1 =
      ( try Out.main (interpret env ast1) with
        | Out.IllegalOut(_) -> raise (EvalError("illegal argument of 'same'"))
      ) in
      let str2 =
      ( try Out.main (interpret env ast2) with
        | Out.IllegalOut(_) -> raise (EvalError("illegal argument of 'same'"))
      ) in
        BooleanConstant((compare str1 str2) == 0)

  | PrimitiveInclude(astfile_name) ->
      ( try
          let str_file_name = Out.main (interpret env astfile_name) in
          let file = open_in str_file_name in
          let parsed = Parser.main Lexer.cut_token (Lexing.from_channel file) in
            interpret env parsed
        with
        | Out.IllegalOut(_) -> raise (EvalError("illegal argument of \\include"))
        | Sys_error(s) -> raise (EvalError("System error at \\include - " ^ s))
      )

  | _ -> raise (EvalError("remains to be implemented"))


and deal_with_cons env argvarcons argcons =
  match (argvarcons, argcons) with
  | (EndOfArgumentVariable, EndOfArgument) -> ()
  | (ArgumentVariableCons(argvar, avtail), ArgumentCons(arg, atail)) ->
      ( add_to_environment env argvar (ref arg) ; deal_with_cons env avtail atail )
  | _ -> raise (EvalError("wrong number of argument"))

(* abstract_tree -> abstract_tree -> (abstract_tree * abstract_tree) *)
and pop_from_separated_tree astin astconstr =
  match astin with
  | Separated(astf, astl) -> (
        match astf with
        | Separated(a, b) -> (
            pop_from_separated_tree astf (compensate astconstr (Separated(UnderConstruction, astl)))
          )
        | _ -> (astf, compensate astconstr astl)
      )
  | _ -> (astin, StringEmpty)

(* abstract_tree -> abstract_tree -> abstract_tree *)
and compensate astunder_constr astcmpnstd =
  match astunder_constr with
  | Separated(astformer, astlatter)
      -> Separated((compensate astformer astcmpnstd), (compensate astlatter astcmpnstd))
  | UnderConstruction -> astcmpnstd
  | astother -> astother

and make_literal_legitimate ast =
  match ast with
  | Concat(astf, astl) ->
        Concat(make_literal_legitimate astf, make_literal_legitimate astl)
  | StringConstant(c) -> StringConstant(c)
  | _ -> raise (EvalError("illegal token in literal area"))