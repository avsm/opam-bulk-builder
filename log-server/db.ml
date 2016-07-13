(* Store values by their hash *)
module type DB = sig
  type t

  val get : t -> string -> string option Lwt.t
  val add : t -> string -> string Lwt.t
  val delete : t -> string -> bool Lwt.t
end

open Lwt.Infix

module Id = struct
  type t = string
  let make v : t = Sha1.(string v |> to_hex)
  let check t =
    (String.length t = 40) &&
    (Astring.String.for_all (function
      |('a'..'z'|'A'..'Z'|'0'..'9') -> true
      |_ -> false) t)
end

module File_db = struct
  (* Directory root *)
  type t = string

  let hash s = Sha1.string s |> Sha1.to_hex

  (* Id must be a valid sha1 hash *)
  let lookup db id =
    Filename.concat db id

  let src = Logs.Src.create ~doc:"file_db" "Db"

  let create ~root_dir =
    Logs.debug ~src (fun p -> p "Created new file db at root %s" root_dir);
    (* TODO check for existence of [root] *)
    root_dir
 
  let get db id =
    Logs.debug ~src (fun p -> p "get key id %s" id);
    Lwt.catch (fun () ->
      let buf = Buffer.create 16384 in
      lookup db id |>
      Lwt_io.lines_of_file |>
      Lwt_stream.iter_s (fun line ->
        Buffer.add_string buf line;
        Buffer.add_char buf '\n';
        Lwt.return_unit
      ) >>= fun () ->
      Lwt.return_some (Buffer.contents buf)
    ) (fun exn ->
      Logs.debug ~src (fun p -> p "not found due to %s" (Printexc.to_string exn));
      Lwt.return_none
    )

  let add db v =
    let id = hash v in
    Logs.debug ~src (fun p -> p "Added item of length %d with hash %s" (String.length v) id);
    let temp_dir = Filename.concat db "tmp" in
    let temp_file = Filename.temp_file ~temp_dir "log" "new" in
    Lwt_io.with_file ~mode:Lwt_io.output temp_file (fun oc -> Lwt_io.write oc v) >>= fun () ->
    Lwt_unix.rename temp_file (lookup db id) >>= fun () ->
    Lwt.return id
  
  let delete db id =
    Lwt.catch (fun () ->
      if Id.check id then
         Lwt_unix.unlink (lookup db id) >>= fun () ->
         Lwt.return_true
      else
         Lwt.return_false
    ) (fun exn -> Lwt.return_false)
end

module Memory_db = struct

  type t = (string, string) Hashtbl.t

  let hash s = Sha1.string s |> Sha1.to_hex
  let src = Logs.Src.create ~doc:"memory_db" "Db"

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

