(* Store values by their hash *)
module type DB = sig
  type t

  val create : unit -> t
  val get : t -> string -> string option Lwt.t
  val add : t -> string -> string Lwt.t
  val delete : t -> string -> bool Lwt.t
end

module Db : DB
