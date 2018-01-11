
module CrossRefHashTable = Hashtbl.Make
  (struct
    type t = string
    let equal = String.equal
    let hash = Hashtbl.hash
  end)


let changed = ref false

let count = ref 0

let count_max = ref 8
  (* temporary *)

let main_hash_table = CrossRefHashTable.create 32
  (* temporary; initial size *)


let initialize () =
  begin
    count := 1;
    CrossRefHashTable.clear main_hash_table;
  end


let needs_another_trial () =
  if !changed then
    begin
      changed := false;
      true
    end
  else
    false


let register (key : string) (value : string) =
  match CrossRefHashTable.find_opt main_hash_table key with
  | None ->
      CrossRefHashTable.add main_hash_table key value

  | Some(value_old) ->
      if String.equal value value_old then () else
        begin
          changed := true;
          CrossRefHashTable.add main_hash_table key value;
        end


let get (key : string) =
  CrossRefHashTable.find_opt main_hash_table key
