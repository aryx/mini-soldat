(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's shared/Weapons.pas, Copyright 2001-2020
 * Transhuman Design, Copyright 2020-2023 OpenSoldat contributors (the
 * MIT License).
 *)

(* See Soldat_weapons.mli *)

type id = Eagles | Mp5 | Ak74 | Steyr | Spas | Ruger | M79 | Barrett | Minimi | Minigun | Socom | Grenade | Hands | Bow | Bow2
type style = Plain | Pellets | Explosive | Thrown | Arrow

type t = {
  id : id;
  name : string;
  damage : float;
  fire_interval : int;
  ammo : int;
  reload_time : int;
  speed : float;
  style : style;
  startup : int;
  movement_acc : float;
  spread : float;
  push : float;
  inherited : float;
  head : float;
  chest : float;
  legs : float;
  clip_reload : bool;
  single_shot : bool;
  clip_out : int;
  clip_in : int;
  timeout : int;
}

(* CreateWeapons: the name as shown, the section's in the file, whether
 * it has a clip (ClipReload), and fires once a pull (FireMode 2) *)
let known : (id * string * string * bool * bool) list =
  [ (Eagles, "Desert Eagles", "Desert Eagles", true, true);
    (Mp5, "HK MP5", "HK MP5", true, false);
    (Ak74, "Ak-74", "Ak-74", true, false);
    (Steyr, "Steyr AUG", "Steyr AUG", true, false);
    (Spas, "Spas-12", "Spas-12", false, true);
    (Ruger, "Ruger 77", "Ruger 77", false, true);
    (M79, "M79", "M79", true, false);
    (Barrett, "Barrett M82A1", "Barret M82A1", true, true);
    (Minimi, "FN Minimi", "FN Minimi", true, false);
    (Minigun, "XM214 Minigun", "XM214 Minigun", false, false);
    (Socom, "USSOCOM", "USSOCOM", true, true);
    (Grenade, "Grenade", "Grenade", false, false);
    (Hands, "Hands", "Punch", false, false);
    (Bow, "Bow", "Rambo Bow", false, false);
    (Bow2, "Flame Bow", "Flamed Arrows", false, false) ]

let primaries : id list = [ Eagles; Mp5; Ak74; Steyr; Spas; Ruger; M79; Barrett; Minimi; Minigun ]

let parse (text : string) : (string * (string * float) list) list =
  let sections =
    String.split_on_char '\n' text
    |> List.fold_left
         (fun sections line ->
           let line = String.trim line in
           let n = String.length line in
           if n > 2 && line.[0] = '[' && line.[n - 1] = ']' then (String.sub line 1 (n - 2), []) :: sections
           else
             match (sections, String.index_opt line '=') with
             | ((name, numbers) :: rest, Some i) when line.[0] <> ';' -> (
                 match float_of_string_opt (String.trim (String.sub line (i + 1) (n - i - 1))) with
                 | Some v -> (name, (String.trim (String.sub line 0 i), v) :: numbers) :: rest
                 | None -> sections)
             | _ -> sections)
         []
  in
  List.rev_map (fun (name, numbers) -> (name, List.rev numbers)) sections

(* BULLET_TIMEOUT and GRENADE_TIMEOUT (shared/Constants.pas) *)
let bullet_timeout = 420
let grenade_timeout = 180

let of_ini (sections : (string * (string * float) list) list) : (id -> t, string) result =
  let weapon (id, name, section, clip_reload, single_shot) : (t, string) result =
    match List.assoc_opt section sections with
    | None -> Error (Printf.sprintf "weapons.ini: no section [%s]" section)
    | Some numbers -> (
        let missing = ref None in
        let number key = match List.assoc_opt key numbers with Some v -> v | None -> missing := Some key; 0. in
        let int key = int_of_float (number key) in
        let style = match int "BulletStyle" with 2 -> Thrown | 3 -> Pellets | 4 -> Explosive | 7 | 8 -> Arrow | _ -> Plain in
        let reload_time = int "ReloadTime" in
        let w =
          {
            id; name; damage = number "Damage"; fire_interval = int "FireInterval"; ammo = int "Ammo"; reload_time; speed = number "Speed"; style;
            startup = int "StartUpTime"; movement_acc = number "MovementAcc"; spread = number "BulletSpread"; push = number "Push";
            inherited = number "InheritedVelocity"; head = number "ModifierHead"; chest = number "ModifierChest"; legs = number "ModifierLegs";
            clip_reload; single_shot;
            clip_out = (if clip_reload then int_of_float (float_of_int reload_time *. 0.8) else 0);
            clip_in = (if clip_reload then int_of_float (float_of_int reload_time *. 0.3) else 0);
            timeout = (if style = Thrown then grenade_timeout else bullet_timeout);
          }
        in
        match !missing with Some key -> Error (Printf.sprintf "weapons.ini: [%s] has no %s" section key) | None -> Ok w)
  in
  let rec all acc = function
    | [] -> Ok (List.rev acc)
    | k :: rest -> ( match weapon k with Ok w -> all (w :: acc) rest | Error e -> Error e)
  in
  Result.map (fun weapons id -> List.find (fun (w : t) -> w.id = id) weapons) (all [] known)

let table : (id -> t) Lazy.t =
  lazy (match of_ini (parse (Base64.decode Weapons_ini.base64)) with Ok get -> get | Error e -> failwith e)

let get (id : id) : t = (Lazy.force table) id

let is_bow (id : id) : bool = id = Bow || id = Bow2

let modifier (w : t) (point : int) : float = if point <= 4 then w.legs else if point <= 11 then w.chest else w.head
