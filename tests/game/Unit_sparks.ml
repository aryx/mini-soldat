(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_sparks.mli *)

let near = Alcotest.float
let floor = Testutil_map.floor ()

(* the sparks' chance, always the same number *)
let chance (x : float) () : float = x

let make ?(random = chance 0.5) (event : Soldat_event.t) = Soldat_sparks.of_event floor ~random ~owner:0 event
let kinds (sparks : Soldat_sparks.t list) : Soldat_sparks.kind list = List.map (fun (s : Soldat_sparks.t) -> s.kind) sparks
let count kind sparks = List.length (List.filter (fun (s : Soldat_sparks.t) -> s.kind = kind) sparks)

(* [n] ticks of some sparks: those left, and all that was heard *)
let fall ?(map = floor) (n : int) (sparks : Soldat_sparks.t list) =
  let rec go n sparks heard =
    if n = 0 then (sparks, heard)
    else
      let (sparks, h) = Soldat_sparks.tick map ~random:(chance 0.5) sparks in
      go (n - 1) sparks (heard @ h)
  in
  go n sparks []

let spark ?(life = 255) kind (x, y) (vx, vy) : Soldat_sparks.t = { kind; x; y; vx; vy; life; owner = 0; hits = 0 }

(* a .wav file of these samples, 8 bits each *)
let wav8 (samples : int list) : string =
  let b = Buffer.create 64 in
  let u16 v = Buffer.add_char b (Char.chr (v land 255)); Buffer.add_char b (Char.chr (v lsr 8)) in
  let u32 v = u16 (v land 0xffff); u16 (v lsr 16) in
  let n = List.length samples in
  Buffer.add_string b "RIFF"; u32 (36 + n); Buffer.add_string b "WAVEfmt ";
  u32 16; u16 1; u16 1; u32 22050; u32 22050; u16 1; u16 8;
  Buffer.add_string b "data"; u32 n;
  List.iter (fun s -> Buffer.add_char b (Char.chr s)) samples;
  Buffer.contents b

let tests =
  Testo.categorize "Sparks and sounds"
    [
      Testo.create "the sounds' files" (fun () ->
          Alcotest.(check string) "a weapon's shot" "ak74-fire" (Soldat_sfx.file (Fire Ak74) 6);
          Alcotest.(check string) "the Barrett's is spelt as its files are" "barretm82-reload" (Soldat_sfx.file (Reload Barrett) 0);
          Alcotest.(check int) "a step is one of four" 4 (Soldat_sfx.variants Step);
          (* 6 mod 4 = 2: the third *)
          Alcotest.(check (list string)) "by a number" [ "step"; "step2"; "step3"; "step4"; "step3" ] (List.map (Soldat_sfx.file Step) [ 0; 1; 2; 3; 6 ]);
          Alcotest.(check int) "86 files in all" 86 (List.length (List.sort_uniq compare Soldat_sfx.files));
          (* each is in data/sfx (the test's dune rule brings them beside it) *)
          List.iter (fun name -> Alcotest.(check bool) (name ^ ".wav is in data/sfx") true (Sys.file_exists ("../../data/sfx/" ^ name ^ ".wav"))) Soldat_sfx.files;
          (* and is what the Playground's Audio reads, once its 8 bits
           * are made 16: plain samples (format 1), not ADPCM's *)
          List.iter
            (fun name ->
              let wav = Soldat_sound.to_16_bit (In_channel.with_open_bin ("../../data/sfx/" ^ name ^ ".wav") In_channel.input_all) in
              let u16 i = Char.code wav.[i] lor (Char.code wav.[i + 1] lsl 8) in
              Alcotest.(check (pair string (pair int int))) (name ^ ".wav: plain samples of 16 bits") ("fmt ", (1, 16)) (String.sub wav 12 4, (u16 20, u16 34)))
            Soldat_sfx.files);
      Testo.create "how loud, and from where" (fun () ->
          let heard at = Soldat_sound.heard ~listener:(100., 50.) at in
          (* 300 to the right: 1 - 300 / 750, and 300 / sqrt (300^2 + 1000^2) *)
          (match heard (400., 50.) with
          | Some (volume, pan) ->
              Alcotest.(check (near 0.001)) "0.6 of its loudness" 0.6 volume;
              Alcotest.(check (near 0.001)) "0.287 to the right" 0.287 pan
          | None -> Alcotest.fail "300 away: not heard");
          Alcotest.(check (option (pair (near 0.001) (near 0.001)))) "where one is: all of it, in the middle" (Some (1., 0.)) (heard (100., 50.));
          Alcotest.(check bool) "above: quieter, in the middle" true (heard (100., -325.) = Some (0.5, 0.));
          Alcotest.(check bool) "to the left: a pan under 0" true (match heard (-200., 50.) with Some (_, pan) -> pan < 0. | None -> false);
          Alcotest.(check bool) "beyond 750: not heard" true (heard (900., 50.) = None));
      Testo.create "an 8-bit recording made 16-bit" (fun () ->
          let out = Soldat_sound.to_16_bit (wav8 [ 128; 255; 0; 129 ]) in
          let u16 i = Char.code out.[i] lor (Char.code out.[i + 1] lsl 8) in
          let s16 i = let v = u16 i in if v >= 32768 then v - 65536 else v in
          Alcotest.(check int) "a header and 4 samples of 2 bytes" (44 + 8) (String.length out);
          Alcotest.(check (list int)) "16 bits, 2 bytes a frame, 44100 bytes a second" [ 16; 2; 44100 ] [ u16 34; u16 32; u16 28 lor (u16 30 lsl 16) ];
          (* (s - 128) x 256 *)
          Alcotest.(check (list int)) "each sample around 0" [ 0; 32512; -32768; 256 ] (List.map s16 [ 44; 46; 48; 50 ]);
          Alcotest.(check string) "a 16-bit file is left as it is" out (Soldat_sound.to_16_bit out);
          Alcotest.(check string) "and what is no .wav too" "nothing" (Soldat_sound.to_16_bit "nothing");
          (* one of Soldat's own, 8-bit: twice its samples after *)
          let chan = open_in_bin "../../data/sfx/step.wav" in
          let step = Fun.protect ~finally:(fun () -> close_in chan) (fun () -> really_input_string chan (in_channel_length chan)) in
          Alcotest.(check bool) "step.wav is 8-bit, and grows" true (String.length (Soldat_sound.to_16_bit step) > String.length step + 1000));
      Testo.create "what an event makes" (fun () ->
          let shot weapon : Soldat_event.t = Shot { weapon; hand = (0., -30.); bullet = (24., 0.); aim = (1., 0.); speed = (0., 0.); facing = 1 } in
          let (sparks, sounds) = make (shot Ak74) in
          Alcotest.(check bool) "a shot: its shell and a puff at the muzzle" true (kinds sparks = [ Shell Ak74; Muzzle ]);
          Alcotest.(check int) "its sound is another event's" 0 (List.length sounds);
          let shell = List.hd sparks in
          (* across the way one aims: aiming right, facing right, downwards (y down) by 0.8 + 0.5 x 0.5 *)
          Alcotest.(check (pair (near 0.001) (near 0.001))) "thrown across the aim" (0., -1.05) (shell.vx, shell.vy);
          Alcotest.(check (pair (near 0.001) (near 0.001))) "from beside the hand" (2. -. (0.015 *. 24.), -32.) (shell.x, shell.y);
          Alcotest.(check int) "the Eagles: two shells" 2 (count (Shell Eagles) (fst (make (shot Eagles))));
          Alcotest.(check bool) "the shotgun: none until it is pumped" true (kinds (fst (make (shot Spas))) = [ Muzzle ]);
          let pumped = fst (make (Pumped { hand = (0., -30.); along = (1., 0.); speed = (0., 0.); facing = 1 })) in
          Alcotest.(check bool) "pumped: its red shell" true (kinds pumped = [ Shell Spas ]);
          Alcotest.(check bool) "a clip let go" true (kinds (fst (make (Clip { weapon = Ak74; hand = (0., -30.); speed = (0., 0.) }))) = [ Clip Ak74 ]);
          Alcotest.(check int) "the Eagles': two" 2 (List.length (fst (make (Clip { weapon = Eagles; hand = (0., -30.); speed = (0., 0.) }))));
          (* a bullet's end *)
          let (sparks, sounds) = make (Wall ((100., -1.), (18., 2.))) in
          Alcotest.(check (pair int int)) "in a wall: three chips and two smokes" (3, 2) (count Chip sparks, count Smoke sparks + count Mini_smoke sparks);
          Alcotest.(check bool) "thrown back from it" true (List.for_all (fun (s : Soldat_sparks.t) -> s.vx <= 0. && s.vy <= 0.) sparks);
          Alcotest.(check bool) "and heard" true (sounds = [ (Soldat_sfx.Ric, (100., -1.)) ]);
          let (sparks, sounds) = make (Ricochet ((100., -1.), (18., 2.))) in
          Alcotest.(check (pair int int)) "a ricochet: five sparks and a grey one" (5, 1) (count Spark sparks, count Spark_grey sparks);
          Alcotest.(check bool) "its own sound" true (List.map fst sounds = [ Soldat_sfx.Ricochet ]);
          (* blood: 4 at least, by chance up to 13 *)
          let blood x = List.length (fst (make ~random:(chance x) (Blood ((0., -20.), (18., 0.))))) in
          Alcotest.(check (pair int int)) "blood: from 4 drops to 13" (4, 13) (blood 0.9, blood 0.01);
          (* an explosion *)
          let (sparks, sounds) = make (Blast (Grenade, (50., -5.))) in
          Alcotest.(check bool) "an explosion: its smoke, its ring, its fire" true (kinds sparks = [ Big_smoke; Smoke_ring; Explosion ]);
          Alcotest.(check (list int)) "190, 50 and 48 ticks" [ 190; 50; 48 ] (List.map (fun (s : Soldat_sparks.t) -> s.life) sparks);
          Alcotest.(check bool) "its sound" true (sounds = [ (Soldat_sfx.Grenade_explosion, (50., -5.)) ]);
          Alcotest.(check bool) "the M79's: smaller, another sound" true
            (let (sparks, sounds) = make (Blast (M79, (50., -5.))) in count Explosion_m79 sparks = 1 && List.map fst sounds = [ Soldat_sfx.M79_explosion ]);
          (* the jets: by chance *)
          let jets x = List.length (fst (make ~random:(chance x) (Jets { feet = ((0., 0.), (4., 0.)); legs = ((0., -1.), (0., -1.)); speed = (0., 0.) }))) in
          Alcotest.(check (pair int int)) "the jets: nothing most ticks; smoke and fire from each foot some" (0, 4) (jets 0.5, jets 0.01));
      Testo.create "a spark's fall" (fun () ->
          (* in the air: gravity 0.06 / 1.4, 0.998 of its speed kept *)
          let (one, _) = fall ~map:Testutil_map.empty 1 [ spark Chip (0., -500.) (2., 0.) ] in
          let s = List.hd one in
          Alcotest.(check (pair (near 0.0001) (near 0.0001))) "moved by its speed and the pull" (2., -500. +. (0.06 /. 1.4)) (s.x, s.y);
          Alcotest.(check (pair (near 0.0001) (near 0.0001))) "its speed after" (2. *. 0.998, 0.06 /. 1.4 *. 0.998) (s.vx, s.vy);
          Alcotest.(check int) "a tick of its life gone" 254 s.life;
          (* its life over: gone *)
          Alcotest.(check int) "a life of 3: there after 2 ticks" 1 (List.length (fst (fall ~map:Testutil_map.empty 2 [ spark ~life:3 Chip (0., -500.) (0., 0.) ])));
          Alcotest.(check int) "gone at the third" 0 (List.length (fst (fall ~map:Testutil_map.empty 3 [ spark ~life:3 Chip (0., -500.) (0., 0.) ])));
          (* an explosion's fire stays where it is *)
          let (fire, _) = fall ~map:Testutil_map.empty 10 [ spark ~life:48 Explosion (7., -500.) (3., 3.) ] in
          Alcotest.(check (pair (near 0.0001) (near 0.0001))) "an explosion does not move" (7., -500.) ((List.hd fire).x, (List.hd fire).y);
          (* a shell on the floor: it bounces, and clinks the 1st, 3rd and 5th time *)
          let (left, heard) = fall 250 [ spark (Shell Ak74) (100., -30.) (1., 0.) ] in
          Alcotest.(check int) "a shell: three clinks" 3 (List.length (List.filter (fun (sfx, _) -> sfx = Soldat_sfx.Shell) heard));
          Alcotest.(check int) "and gone at its sixth bounce" 0 (List.length left);
          let (_, heard) = fall 250 [ spark (Clip Ak74) (100., -30.) (0., 0.) ] in
          Alcotest.(check int) "a clip: heard twice" 2 (List.length heard);
          (* a chip goes through the floor: only some sparks meet the map *)
          let (left, _) = fall 100 [ spark Chip (100., -30.) (0., 0.) ] in
          Alcotest.(check bool) "a chip falls through" true ((List.hd left).y > 20.);
          (* blood leaves a splat where it lands *)
          let (left, _) = fall 40 [ spark ~life:80 Blood (100., -30.) (0., 0.) ] in
          Alcotest.(check bool) "a drop of blood: a splat on the floor" true (count Splat left >= 1);
          (* too many: the oldest go *)
          let before = !Soldat_sparks.most in
          Soldat_sparks.most := 3;
          let kept = Soldat_sparks.capped (List.init 5 (fun i -> spark ~life:(10 + i) Chip (0., 0.) (0., 0.))) in
          Soldat_sparks.most := before;
          Alcotest.(check (list int)) "over the most: the last made are kept" [ 12; 13; 14 ] (List.map (fun (s : Soldat_sparks.t) -> s.life) kept);
          (* an explosion's first ticks shake the camera, by a sixth of its life at most *)
          let (wx, wy) = Soldat_sparks.wobble ~random:(chance 0.99) [ spark ~life:48 Explosion (0., 0.) (0., 0.) ] in
          Alcotest.(check bool) "an explosion shakes the picture" true (wx = 8. && wy = 7.);
          Alcotest.(check bool) "not after its first 11 ticks" true (Soldat_sparks.wobble ~random:(chance 0.99) [ spark ~life:36 Explosion (0., 0.) (0., 0.) ] = (0., 0.)));
      Testo.create "what a tick says was heard" (fun () ->
          let start () = Soldat_update.start ~bots:(Soldat_bots.cast 2 0) Testutil_map.rooms in
          let play (p : Soldat_model.play) n keys =
            let p = ref p and heard = ref [] in
            for _ = 1 to n do
              let me = !p.soldiers.(0).body in
              p := Soldat_update.tick !p (keys { Soldat_soldier.no_control with aim = (me.x +. 1000., me.y -. 12.) }) ~look:(0., 0.);
              heard := !heard @ List.map fst !p.sounds
            done;
            (!p, !heard)
          in
          let has sfx heard = List.mem sfx heard in
          (* dropped from 20 above the floor it lands at 1.5 a tick: too
           * softly to be heard (a fall is heard from 2.2, a hard one
           * from 3.5) *)
          let (p, heard) = play (start ()) 100 Fun.id in
          Alcotest.(check bool) "a small drop: no sound" false (has Soldat_sfx.Fall heard || has Soldat_sfx.Fall_hard heard);
          (* higher: a speed gains 0.06 a tick and keeps 0.99 of itself,
           * which from 100 above is 2.7 at the floor, from 250, 3.9 *)
          let from height = { p with soldiers = Array.mapi (fun i (s : Soldat_model.soldier) -> if i = 0 then { s with body = Soldat_soldier.create ~primary:Ak74 (s.body.x, -.height) 190 } else s) p.soldiers } in
          let landing height = snd (play (from height) 200 Fun.id) in
          Alcotest.(check bool) "from 100 above: a fall" true (has Soldat_sfx.Fall (landing 100.) && not (has Soldat_sfx.Fall_hard (landing 100.)));
          Alcotest.(check bool) "from 250: a hard one" true (has Soldat_sfx.Fall_hard (landing 250.));
          Alcotest.(check bool) "standing still: nothing more" true (snd (play p 60 Fun.id) = []);
          (* a run: a step every 16 frames of its animation *)
          let (_, heard) = play p 100 (fun c -> { c with right = true }) in
          let steps = List.length (List.filter (( = ) Soldat_sfx.Step) heard) in
          Alcotest.(check bool) (Printf.sprintf "running 100 ticks: steps (%d)" steps) true (steps >= 4 && steps <= 7);
          Alcotest.(check bool) "a jump" true (has Soldat_sfx.Jump (snd (play p 5 (fun c -> { c with up = true }))));
          Alcotest.(check bool) "lying down" true (has Soldat_sfx.Go_prone (snd (play p 5 (fun c -> { c with prone = true }))));
          (* a shot, its shell on the floor a moment later, the sparks it left *)
          let (q, heard) = play p 1 (fun c -> { c with fire = true }) in
          Alcotest.(check bool) "a shot" true (heard = [ Soldat_sfx.Fire Ak74 ]);
          Alcotest.(check int) "its shell and its puff are in the round" 2 (List.length q.sparks);
          let (_, heard) = play q 120 Fun.id in
          Alcotest.(check bool) "the shell on the floor" true (has Soldat_sfx.Shell heard);
          (* an empty clip: the reload's sound, once *)
          (* 40 rounds every 11 ticks, then 150 of reload: 560 ticks in, it is not over *)
          let (_, heard) = play p 560 (fun c -> { c with fire = true }) in
          Alcotest.(check int) "40 shots" 40 (List.length (List.filter (( = ) (Soldat_sfx.Fire Ak74)) heard));
          Alcotest.(check int) "then its reload, once" 1 (List.length (List.filter (( = ) (Soldat_sfx.Reload Ak74)) heard));
          Alcotest.(check bool) "and its clip on the floor" true (has Soldat_sfx.Clip_fall heard);
          (* a grenade: pulled, thrown, bouncing, exploding *)
          let n = ref 0 in
          let (_, heard) = play p 300 (fun c -> incr n; { c with grenade = !n <= 30 }) in
          Alcotest.(check bool) "a grenade: its pin, its throw, its bounce, its explosion" true
            (List.for_all (fun sfx -> has sfx heard) [ Soldat_sfx.Grenade_pullout; Grenade_throw; Grenade_bounce; Grenade_explosion ]);
          (* killed: its cry, its body on the floor *)
          let (hx, hy) = Soldat_soldier.point p.soldiers.(0).body 12 in
          let shot = Soldat_bullets.of_shot ~owner:1 { from = (hx -. 2., hy -. 60.); velocity = (0., 55.); weapon = Barrett } in
          let (_, heard) = play { p with bullets = [ shot ] } 120 Fun.id in
          Alcotest.(check bool) "a head off: its sound, and blood" true (has Soldat_sfx.Headchop heard && has Soldat_sfx.Hit_arg heard);
          Alcotest.(check bool) "the body falls" true (has Soldat_sfx.Bodyfall heard);
          Alcotest.(check bool) "the weapon it held too" true (has Soldat_sfx.Weapon_hit heard));
      Testo.create "nothing of it changes the game" (fun () ->
          let round () =
            let p = ref (Soldat_update.start ~bots:(Soldat_bots.cast 3 1) (Lazy.force Soldat_map.arena2)) in
            for _ = 1 to 1500 do
              p := Soldat_update.tick !p Soldat_model.still ~look:(0., 0.)
            done;
            !p
          in
          let places (p : Soldat_model.play) = Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> (s.body.x, s.body.y, s.kills, s.health)) p.soldiers) in
          let with_sparks = round () in
          let before = !Soldat_sparks.most in
          Soldat_sparks.most := 0;
          let without = Fun.protect ~finally:(fun () -> Soldat_sparks.most := before) round in
          Alcotest.(check bool) "there were sparks" true (with_sparks.sparks <> [] && without.sparks = []);
          Alcotest.(check bool) "the same round with and without them" true (places with_sparks = places without);
          Alcotest.(check bool) "and the same sparks twice" true ((round ()).sparks = with_sparks.sparks));
    ]
