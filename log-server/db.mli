(* Store values by their hash *)
module type DB = sig
  type t

  val get : t -> string -> string option Lwt.t
  val add : t -> string -> string Lwt.t
  val delete : t -> string -> bool Lwt.t
end

module Memory_db : sig
  include DB
  val create : unit -> t
end

module File_db : sig
  include DB
  val create : root_dir:string -> t
end
