open Lwt.Infix

type t = 
  < add : string -> string Lwt.t; delete : string -> bool Lwt.t;
    get : string -> string option Lwt.t >

module Id = struct
  type t = string
  let make v : t = Sha1.(string v |> to_hex)
  let check t =
    (String.length t = 40) &&
    (Astring.String.for_all (function
      |('a'..'z'|'A'..'Z'|'0'..'9') -> true
      |_ -> false) t)
end

let file db =

  let lookup id =
    if Id.check id then
      Filename.concat db id
    else 
      raise (Failure "invalid id")
  in
  let src = Logs.Src.create ~doc:"file_db" "Db" in
  let _  = Logs.info (fun p -> p "Using file database at %s" db) in

  object
 
  method get id =
    Logs.debug ~src (fun p -> p "get key id %s" id);
    Lwt.catch (fun () ->
      let buf = Buffer.create 16384 in
      lookup id |>
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

  method add v =
    let id = Id.make v in
    Logs.debug ~src (fun p -> p "Added item of length %d with hash %s" (String.length v) id);
    let temp_file = Filename.temp_file ~temp_dir:db "tmp_" "_tmp" in
    Lwt_io.with_file ~mode:Lwt_io.output temp_file (fun oc -> Lwt_io.write oc v) >>= fun () ->
    Lwt_unix.rename temp_file (lookup id) >>= fun () ->
    Lwt.return id
  
  method delete id =
    Lwt.catch (fun () ->
      if Id.check id then
         Lwt_unix.unlink (lookup id) >>= fun () ->
         Lwt.return_true
      else
         Lwt.return_false
    ) (fun exn -> Lwt.return_false)
end

let memory () =
  let src = Logs.Src.create ~doc:"memory_db" "Db" in
  let db =
    Logs.debug ~src (fun p -> p "Created new database");
    Hashtbl.create 3
  in
  object
  method get id =
    try
      let v = Hashtbl.find db id in
      Logs.debug ~src (fun p -> p "Found item: id %s (length %d)" id (String.length v));
      Lwt.return_some v
    with Not_found ->
      Logs.debug ~src (fun p -> p "Not found: id %s" id);
      Lwt.return_none

  method add v =
    let h = Id.make v in
    Logs.debug ~src (fun p -> p "Added item of length %d with hash %s" (String.length v) h);
    Hashtbl.replace db h v;
    Lwt.return h

  method delete id =
    try
      let _ = Hashtbl.find db id in
      Hashtbl.remove db id;
      Logs.debug ~src (fun p -> p "Removed item hash %s" id);
      Lwt.return_true
    with Not_found ->
      Logs.debug ~src (fun p -> p "Failed to remove item hash %s as not found" id);
      Lwt.return_false
end

