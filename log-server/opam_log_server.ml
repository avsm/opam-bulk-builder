open Cohttp_lwt_unix
open Lwt.Infix

(* Apply the [Webmachine.Make] functor to the Lwt_unix-based IO module
 * exported by cohttp. For added convenience, include the [Rd] module
 * as well so you don't have to go reaching into multiple modules to
 * access request-related information. *)
module Wm = struct
  module Rd = Webmachine.Rd
  include Webmachine.Make(Cohttp_lwt_unix_io)
end

(** A resource for querying all the items in the database via GET and creating
    a new item via POST. Check the [Location] header of a successful POST
    response for the URI of the item. *)
class items (db:Db.t) = object(self)
  inherit [Cohttp_lwt_body.t] Wm.resource

  method allowed_methods rd =
    Wm.continue [`POST] rd

  method content_types_provided rd =
    Wm.continue [ "text/plain", (Wm.continue (`Empty)) ] rd

  method content_types_accepted rd =
    Wm.continue [] rd

  method process_post rd =
    Cohttp_lwt_body.to_string rd.Wm.Rd.req_body >>= fun body ->
    Logs.debug (fun p -> p "Got log body of length %d" (String.length body));
    db#add body >>= fun new_id ->
    Wm.Rd.redirect ("/log/" ^ new_id) rd |>
    Wm.continue true
end

(** A resource for querying an individual item in the database by id via GET,
    modifying an item via PUT, and deleting an item via DELETE. *)
class item (db:Db.t) = object(self)
  inherit [Cohttp_lwt_body.t] Wm.resource

  method private to_json rd =
    db#get (self#id rd)
    >>= function
      | None       -> assert false
      | Some value -> Wm.continue (`String value) rd

  method allowed_methods rd =
    Wm.continue [`GET; `HEAD; `DELETE] rd

  method resource_exists rd =
    let id = self#id rd in
    db#get (self#id rd)
    >>= function
      | None   ->
         Logs.debug (fun p -> p "resource_exists: false for %s" id);
         Wm.continue false rd
      | Some _ ->
         Logs.debug (fun p -> p "resource_exists: true for %s" id);
         Wm.continue true rd

  method content_types_provided rd =
    Wm.continue [
      "application/json", self#to_json
    ] rd

  method content_types_accepted rd =
    Wm.continue [] rd

  method delete_resource rd =
    db#delete (self#id rd)
    >>= fun deleted ->
      let resp_body =
        if deleted
          then `String "{\"status\":\"ok\"}"
          else `String "{\"status\":\"not found\"}"
      in
      Wm.continue deleted { rd with Wm.Rd.resp_body }

  method private id rd =
    Wm.Rd.lookup_path_info_exn "id" rd
end

let main () =
  (* listen on port 8080 *)
  let port = 8080 in
  Logs.info (fun p -> p "Listening on port %d" port);
  (* create the database *)
  let db = Db.file "./db" in
  (* the route table *)
  let routes = [
    ("/logs", fun () -> new items db) ;
    ("/log/:id", fun () -> new item db) ;
  ] in
  let callback (ch,conn) request body =
    let open Cohttp in
    (* Perform route dispatch. If [None] is returned, then the URI path did not
     * match any of the route patterns. In this case the server should return a
     * 404 [`Not_found]. *)
    Wm.dispatch' routes ~body ~request
    >|= begin function
      | None        -> (`Not_found, Header.init (), `String "Not found", [])
      | Some result -> result
    end
    >>= fun (status, headers, body, path) ->
      Logs.debug (fun p -> p "%d - %s %s (%s)"
        (Code.code_of_status status)
        (Code.string_of_method (Request.meth request))
        (Uri.path (Request.uri request))
        (String.concat ", " path));
      (* Finally, send the response to the client *)
      Server.respond ~headers ~body ~status ()
  in
  (* create the server and handle requests with the function defined above *)
  let conn_closed (ch,conn) =
    Logs.info (fun p -> p "connection %s closed"
      (Sexplib.Sexp.to_string_hum (Conduit_lwt_unix.sexp_of_flow ch)))
  in
  let config = Server.make ~callback ~conn_closed () in
  Server.create  ~mode:(`TCP(`Port port)) config
  >>= (fun () -> Printf.eprintf "hello_lwt: listening on 0.0.0.0:%d%!" port;
      Lwt.return_unit)

let setup_log style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

(* Command line interface *)

let run_lwt () = Lwt_main.run (main ())
open Cmdliner

let setup_log =
  Term.(const setup_log $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let main () =
  match Term.(eval (const run_lwt $ setup_log, Term.info "opam-log")) with
  | `Error _ -> exit 1
  | _ -> exit (if Logs.err_count () > 0 then 1 else 0)

let () = main ()
