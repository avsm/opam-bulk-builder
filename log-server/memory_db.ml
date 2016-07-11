(* Store values by their hash *)
module type DB = sig
  type t

  val create : unit -> t
  val get : t -> string -> string option Lwt.t
  val add : t -> string -> string Lwt.t
  val delete : t -> string -> bool Lwt.t
end

module Db : DB = struct

  type t = (string, string) Hashtbl.t

  let hash s = Sha1.string s |> Sha1.to_hex
  let src = Logs.Src.create ~doc:"database" "Db"

  let create () =
    Logs.debug ~src (fun p -> p "Created new database");
    Hashtbl.create 3

  let get db id =
    try
      let v = Hashtbl.find db id in
      Logs.debug ~src (fun p -> p "Found item: id %s (length %d)" id (String.length v));
      Lwt.return_some v
    with Not_found ->
      Logs.debug ~src (fun p -> p "Not found: id %s" id);
      Lwt.return_none

  let add db v =
    let h = hash v in
    Logs.debug ~src (fun p -> p "Added item of length %d with hash %s" (String.length v) h);
    Hashtbl.replace db h v;
    Lwt.return h

  let delete db id =
    try
      let _ = Hashtbl.find db id in
      Hashtbl.remove db id;
      Logs.debug ~src (fun p -> p "Removed item hash %s" id);
      Lwt.return_true
    with Not_found ->
      Logs.debug ~src (fun p -> p "Failed to remove item hash %s as not found" id);
      Lwt.return_false
end

