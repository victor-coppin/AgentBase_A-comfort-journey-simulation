;:::::::::::::::::::::::::::::::;
;        VARIABLES              ;
;:::::::::::::::::::::::::::::::;

;---------- BREEDS ------------;
;---> BREEDS FOR VISUAL
breed [crosswalk-lines crosswalk-line] ; used to sprout cross-line visuals (fat-line, fat-line-bike)
breed [dash-turtles dash-turtle] ; these dash-turtles are the ones that draw the dashed lines on the road
;---> AGENTS
; each agent has its own ghost (see 'Ghost process' in ODD)
breed [cars car]
breed [bikes bike]
breed [ghost-cars ghost-car]
breed [ghost-bikes ghost-bike]

;---------- GLOBALS -----------;
globals [
;---> Defined colors:
; used for clarity : mainly for the RGB color values
  road-color
  sidewalk-color
  building-color
  bike-lane-color
;---> Defined entry and exit points (see "Entry/Exit Point Data Structure" in ODD):
  entry-points ;-> nested list that defines entry properties
  exit-points  ;-> same structure as entry-points
  route-pairs ;-> links each entry and exit to create "linked roads"
  lane-pairs  ;-> links each bike entry to a nearby road entry

;--> Defined scores
; these variables are used to store the metrics (see 'Metrics and Reporters' in ODD)
  efficiency-scores;-> stores the ratio of ghost travel time to real agent travel time
  frustration-scores ;-> stores a rate based on the agent's final mood, acts as a penalty weight
  comfort-scores ;-> the main metric, combining efficiency and a weighted frustration penalty
]

;---------- OWN VARIABLES ------;
patches-own [
  meaning ;-> Defines the patch surface: a road, a bike lane, a park, etc.
  lane-direction ;-> The direction of the road, i.e. 'N-S' or 'W-E'
  bike-lane-direction
  bike-priority? ; If true, bikes on this patch have priority over other agents
]
;-> set attributes to each turtles agents :
turtles-own [
  ;-> Each agent/ghost knows its corresponding ghost/agent:
  my-ghost
  my-real-agent

  ;-> Core properties for movement and measurement:
  speed
  destination-point ;-> Stores the exit point of the trajectory
  my-path ;-> The agent's assigned route, i.e. "C->D"
  start-tick
  travel-time
  finished?
]
cars-own [
  mood ;-> Tracks frustration, used in the calculation of the frustration-score
]

ghost-cars-own [
  mood ;-> Used only to avoid bugs during the creation of the ghost agent; it should have the same attributes as the real agents
]
bikes-own [
   preferred-lane-type ;-> Allows a bike to decide between a road or a bike lane (see 'Switch to bike-lane' in ODD)
   mood ;-> tracks a bike's frustration
]

ghost-bikes-own [
  ;-> Same logic as ghost-cars-own : required to prevent crash but unused.
  preferred-lane-type
  mood
]

;:::::::::::::::::::::::::::::::;
;        PROCEDURES             ;
;:::::::::::::::::::::::::::::::;

;---------- SETUP  --------------;
to setup
  clear-all
  resize-world -16 16 -16 16 ;-> Ensures the world has the exact dimensions this model requires
  set-patch-size 20
  set-colors
;--> Map drawing
; The order of these procedures is critical, as they draw on top of each other.
; We draw from the ground up: base terrain, then roads, then details.
  draw-building
  draw-parking
  draw-park
  draw-bike-lane
  draw-road
  draw-sidewalk
  draw-white-line-center
  draw-dash-line-horizontal
  draw-dash-line-vertical
  plant-trees
  define-priority-patches
  define-entry-and-exit-points
  define-routes
  define-lane-pairs
;--> Instantiate empty lists that will collect the performance data from all finished agents
  set efficiency-scores []
  set comfort-scores []
  set frustration-scores []
  reset-ticks
end

;---------- COLOR CONSTANTS -----------;
;---> labelize colors for clarity
to set-colors
  set road-color rgb 144 144 167 ;-> allow to use 'road-color' instead of 'rgb 144 144 167'
  set sidewalk-color rgb 226 222 215
  set building-color rgb 253 202 131
  set bike-lane-color rgb 191 211 190
end

;-------------------------------------;
;           MAP CREATION              ;
;-------------------------------------;

;---------* INFRASTRUCTURE *----------;
;    (buildings, parking, park)       ;
to draw-building
  ask patches [
    set pcolor white
    set meaning "blank"
  ]
  ask patches with [pycor >= -3] [
    set pcolor building-color
    set meaning "building"
  ]
  ask patches with [pycor <= -10] [
    set pcolor building-color
    set meaning "building"
  ]
end

to draw-park
  ask patches with [pxcor >= 12 and pycor <= -10] [
    set pcolor rgb 130 206 143
    set meaning "park"
  ]
end

to plant-trees
  let excluded-coords [[15 -16] [13 -16] [14 -14] [12 -10][13 -10] [14 -10] [15 -10] [16 -10] [12 -14] [12 -13] [13 -13][14 -13][15 -13] [16 -13][16 -10]]
  ask patches with [
    meaning = "park" and
    not member? (list pxcor pycor) excluded-coords
  ] [
    sprout 1 [
      set shape "tree"
      set color green
      set size 1
      set heading 0
      setxy pxcor pycor
    ]
  ]
  let nice-street-coords [[-1 -14] [2 -14] [5 -14] [8 -14] ]
  foreach nice-street-coords [coord ->
    ask patch (item 0 coord) (item 1 coord) [
      sprout 1 [
        set shape "tree"
        set color green
        set size 0.8
        set heading 0
      ]
    ]
  ]
end

to draw-parking
  ask patches with [pxcor >= 10 and pycor >= 5 and pycor <= 10] [
    set pcolor rgb 74 71 71
    set meaning "parking"
  ]
end

;---------* TRANSPORTATION *----------;
;   (roads, bike lanes, sidewalks)    ;
to draw-bike-lane
  ask patches with [pycor = -5] [ set pcolor bike-lane-color set meaning "bike-lane" set bike-lane-direction "E-W" ]
  ask patches with [pycor >= -4 and pxcor = 4] [ set pcolor bike-lane-color set meaning "bike-lane" set bike-lane-direction "N-S" ]
  ask patches with [pycor >= -4 and pxcor = 8] [ set pcolor bike-lane-color set meaning "bike-lane" set bike-lane-direction "S-N" ]
  ask patches with [pycor <= -10 and pxcor = 11] [ set pcolor bike-lane-color set meaning "bike-lane" set bike-lane-direction "S-N" ]
end

to draw-road
  ask patches [
    if pycor = -8 [ set pcolor road-color set meaning "road" set lane-direction "W-E" ]
    if pycor = -6 [ set pcolor road-color set meaning "road" set lane-direction "E-W" ]
    if pycor = -7 [ set pcolor rgb 165 165 192 set meaning "road-center" set lane-direction "" ]
    if pxcor <= -5 [
      if pycor = 6 [ set pcolor road-color set meaning "road" set lane-direction "E-W" ]
      if pycor = 5 [ set pcolor rgb 165 165 192 set meaning "road-center" set lane-direction "" ]
      if pycor = 4 [ set pcolor road-color set meaning "road" set lane-direction "W-E" ]
    ]
    if pycor >= -5 [
      if pxcor = 5 [ set pcolor road-color set meaning "road" set lane-direction "N-S" ]
      if pxcor = 6 [ set pcolor rgb 165 165 192 set meaning "road-center" set lane-direction "" ]
      if pxcor = 7 [ set pcolor road-color set meaning "road" set lane-direction "S-N" ]
    ]
    if pxcor = -11 [ set pcolor road-color set meaning "road" set lane-direction "N-S" ]
    if pxcor = -4 [ set pcolor road-color set meaning "road" set lane-direction "S-N" ]
  ]
  let connection-road-coords [ [9 5 "W-E"] [8 5 "W-E"] [8 10 "E-W"] [9 10 "E-W"] ]
  foreach connection-road-coords [ coord ->
    let x item 0 coord
    let y item 1 coord
    let dir item 2 coord
    ask patch x y [ set pcolor road-color set meaning "road" set lane-direction dir ]
  ]
end

to define-priority-patches
  ask patches [ set bike-priority? false ]
  let priority_patches_list (list (patch -11 -5) (patch -4 -5))
  ask (patch-set priority_patches_list) [
    set bike-priority? true
    sprout-crosswalk-lines 1 [
      set shape "fat-line-bike"
      set color bike-lane-color
      set size 0.8
    ]
  ]
end

to draw-sidewalk
  ask patches with [pxcor <= -12 and pycor >= 7 and any? neighbors with [pcolor = road-color]] [ set pcolor sidewalk-color ]
  ask patches with [pxcor <= -12 and pycor >= -4 and pycor <= 3 and any? neighbors with [pcolor = road-color or pcolor = bike-lane-color]] [ set pcolor sidewalk-color ]
  ask patches with [pxcor <= -12 and pycor <= -9 and any? neighbors4 with [pcolor = road-color]] [ set pcolor sidewalk-color ]
  ask patches with [pxcor >= -10 and pxcor <= -5 and pycor >= 7 and any? neighbors with [pcolor = road-color]] [ set pcolor sidewalk-color ]
  ask patches with [pxcor >= -10 and pxcor <= -5 and pycor >= -4 and pycor <= 3 and any? neighbors with [pcolor = road-color or pcolor = bike-lane-color]] [ set pcolor sidewalk-color ]
  ask patches with [pxcor >= -10 and pxcor <= -5 and pycor <= -9 and any? neighbors with [pcolor = road-color]] [ set pcolor sidewalk-color ]
  ask patches with [abs pxcor <= 3 and pycor >= -4 and any? neighbors with [pcolor = road-color or pcolor = bike-lane-color]] [ set pcolor sidewalk-color ]
  ask patches with [pxcor >= -3 and pycor <= -9 and any? neighbors4 with [pcolor = road-color]] [ set pcolor sidewalk-color ]
  ask patch 5 -16 [ set pcolor building-color ]
  ask patch 7 -16 [ set pcolor building-color ]
  ask patches with [pxcor >= 9 and pycor >= 11 and any? neighbors4 with [pcolor = road-color or pcolor = rgb 74 71 71 or pcolor = bike-lane-color]] [ set pcolor sidewalk-color ]
  ask patch 11 16 [ set pcolor building-color ]
  ask patches with [pxcor >= 9 and abs pycor <= 4 and any? neighbors4 with [pcolor = road-color or pcolor = rgb 74 71 71 or pcolor = bike-lane-color]] [ set pcolor sidewalk-color ]
  ask patches with [pxcor = 9 and pycor >= 6 and pycor <= 9] [ set pcolor sidewalk-color ]
  ask patches with [pxcor >= -2 and pxcor <= 9 and pycor >= -15 and pycor <= -13] [ set pcolor sidewalk-color ]
  ask patches with [pycor <= -10 and pxcor = 10] [ set pcolor sidewalk-color ]
end

to draw-crosswalk-lines [x-coords y-coords heading-val]
  foreach x-coords [ xval ->
    foreach y-coords [ yval ->
      ask patch xval yval [ sprout-crosswalk-lines 1 [ set shape "fat-line" set color white set heading heading-val set size 0.8 ] ]
    ]
  ]
end

to draw-white-line-center
  draw-crosswalk-lines [5 6 7] [-4 11] 90
  draw-crosswalk-lines [-11 -4] [-9 -4 3 7] 90
  draw-crosswalk-lines [3 -6 9] [-6 -7 -8] 0
  draw-crosswalk-lines [-6] [4 5 6] 0
  draw-crosswalk-lines [9] [5 10] 0
end

to draw-dash-line-horizontal
  create-dash-turtles 1 [ setxy -16.5 -7 set heading 90 set color white set size 0.4 while [pxcor <= 2] [ if pcolor = rgb 165 165 192 [ pen-down fd 0.2 pen-up fd 0.2 ] if pcolor != rgb 165 165 192 [ fd 0.4 ] ] die ]
  create-dash-turtles 1 [ setxy 16 -7 set heading 270 set color white set size 0.4 while [pxcor >= 10] [ if pcolor = rgb 165 165 192 [ pen-down fd 0.2 pen-up fd 0.2 ] if pcolor != rgb 165 165 192 [ fd 0.4 ] ] die ]
  create-dash-turtles 1 [ setxy -16.5 5 set heading 90 set color white set size 0.4 while [pxcor <= -5 and pycor = 5] [ if pcolor = rgb 165 165 192 [ pen-down fd 0.2 pen-up fd 0.2 ] if pcolor != rgb 165 165 192 [ fd 0.4 ] ] die ]
end

to draw-dash-line-vertical
  create-dash-turtles 1 [ setxy 6 16 set heading 180 set color white set size 0.4 while [pycor >= -5] [ if pcolor = rgb 165 165 192 [ pen-down fd 0.2 pen-up fd 0.2 ] if pcolor != rgb 165 165 192 [ fd 0.4 ] ] die ]
  ask patches with [pcolor = rgb 165 165 192] [ set pcolor road-color ]
end

;-------------------------------------;
;       TRAFFIC CONFIGURATION         ;
;-------------------------------------;
to define-entry-and-exit-points
  set entry-points [ ["A" -16 -8 90 "car/bike"] ["C" 16 -6 270 "car/bike"] ["E" 16 -5 270 "bike"] ["G" -11 16 180 "car/bike"] ["I" -4 -16 0 "car/bike"] ]
  set exit-points [ ["B" 16 -8 90 "car/bike"] ["D" -16 -6 270 "car/bike"] ["F" -16 -5 270 "bike"] ["H" -11 -16 180 "car/bike"] ["J" -4 16 0 "car/bike"] ]
end

to define-routes
  set route-pairs [ ["A" "B"] ["C" "D"] ["E" "F"] ["G" "H"] ["I" "J"] ]
end

to define-lane-pairs
  set lane-pairs [ ["C" "E"] ]
end

to-report get-entry-point [labelS]
  report first filter [[pt] -> item 0 pt = labelS] entry-points
end

to-report get-exit-point [labelE]
  report first filter [[pt] -> item 0 pt = labelE] exit-points
end

to-report is-route-active? [route-name]
  if route-name = "A->B" [ report route-AB-active? ]
  if route-name = "C->D" [ report route-CD-active? ]
  if route-name = "E->F" [ report route-EF-active? ]
  if route-name = "G->H" [ report route-GH-active? ]
  if route-name = "I->J" [ report route-IJ-active? ]
  report false
end

;-------------------------------------;
;               SCORE METRICS         ;
;-------------------------------------;
to-report report-metrics-global-overall
  if-else empty? comfort-scores [
    report "N/A"
  ] [
    let comfort-vals map [entry -> item 2 entry] comfort-scores
    let efficiency-vals map [entry -> item 2 entry] efficiency-scores
    let frustration-vals map [entry -> item 2 entry] frustration-scores
    let avg-comfort (precision (mean comfort-vals) 2)
    let avg-efficiency (precision (mean efficiency-vals) 2)
    let avg-frustration ( (precision (mean frustration-vals) 2) * -1 )
    report (word avg-comfort " (" avg-efficiency " " avg-frustration ")")
  ]
end

to-report report-metrics-global-for-breed [agent-breed]
  let breed-comfort filter [entry -> item 1 entry = agent-breed] comfort-scores
  let breed-efficiency filter [entry -> item 1 entry = agent-breed] efficiency-scores
  let breed-frustration filter [entry -> item 1 entry = agent-breed] frustration-scores
  if-else empty? breed-comfort [
    report "N/A"
  ] [
    let comfort-vals map [entry -> item 2 entry] breed-comfort
    let efficiency-vals map [entry -> item 2 entry] breed-efficiency
    let frustration-vals map [entry -> item 2 entry] breed-frustration
    let avg-comfort (precision (mean comfort-vals) 2)
    let avg-efficiency (precision (mean efficiency-vals) 2)
    let avg-frustration ( (precision (mean frustration-vals) 2) * -1 )
    report (word avg-comfort " (" avg-efficiency " " avg-frustration ")")
  ]
end

to-report report-metrics-for-route-overall [route-name]
  let route-comfort filter [entry -> item 0 entry = route-name] comfort-scores
  let route-efficiency filter [entry -> item 0 entry = route-name] efficiency-scores
  let route-frustration filter [entry -> item 0 entry = route-name] frustration-scores
  if-else empty? route-comfort [
    report "N/A"
  ] [
    let comfort-vals map [entry -> item 2 entry] route-comfort
    let efficiency-vals map [entry -> item 2 entry] route-efficiency
    let frustration-vals map [entry -> item 2 entry] route-frustration
    let avg-comfort (precision (mean comfort-vals) 2)
    let avg-efficiency (precision (mean efficiency-vals) 2)
    let avg-frustration ( (precision (mean frustration-vals) 2) * -1 )
    report (word avg-comfort " (" avg-efficiency " " avg-frustration ")")
  ]
end

to-report report-metrics-for-breed [route-name agent-breed]
  let route-comfort filter [entry -> (item 0 entry = route-name) and (item 1 entry = agent-breed)] comfort-scores
  let route-efficiency filter [entry -> (item 0 entry = route-name) and (item 1 entry = agent-breed)] efficiency-scores
  let route-frustration filter [entry -> (item 0 entry = route-name) and (item 1 entry = agent-breed)] frustration-scores
  if-else empty? route-comfort [
    report "N/A"
  ] [
    let comfort-vals map [entry -> item 2 entry] route-comfort
    let efficiency-vals map [entry -> item 2 entry] route-efficiency
    let frustration-vals map [entry -> item 2 entry] route-frustration
    let avg-comfort (precision (mean comfort-vals) 2)
    let avg-efficiency (precision (mean efficiency-vals) 2)
    let avg-frustration ( (precision (mean frustration-vals) 2) * -1 )
    report (word avg-comfort " (" avg-efficiency " " avg-frustration ")")
  ]
end

;------------ AGENT SPAWN & MOVEMENT -----;
to spawn-vehicle-at-entry [entry-label exit-label]
  let entry get-entry-point entry-label
  let exit-list get-exit-point exit-label
  let vx item 1 entry
  let vy item 2 entry
  let vh item 3 entry
  let vtype item 4 entry
  let allowed-types []
  if vtype = "car/bike" [ set allowed-types lput "car" allowed-types ]
  if (vtype = "car/bike") or (vtype = "bike") [ set allowed-types lput "bike" allowed-types ]
  if pending-cars = 0 or not member? "car" allowed-types [ set allowed-types remove "car" allowed-types ]
  if pending-bikes = 0 or not member? "bike" allowed-types [ set allowed-types remove "bike" allowed-types ]
  if (length allowed-types) > 0 and not any? turtles-on patch vx vy [
    let choice one-of allowed-types
    if choice = "car" [
      let new-car nobody
      let new-ghost nobody
      create-cars 1 [
        setup-vehicle vx vy vh exit-list "car"
        set my-path (word entry-label "->" exit-label)
        set new-car self
      ]
      create-ghost-cars 1 [
        setup-ghost-vehicle vx vy vh exit-list "car" new-car
        set new-ghost self
      ]
      ask new-car [ set my-ghost new-ghost ]
      set pending-cars pending-cars - 1
    ]
    if choice = "bike" [
      let new-bike nobody
      let new-ghost nobody
      create-bikes 1 [
        setup-vehicle vx vy vh exit-list "bike"
        set my-path (word entry-label "->" exit-label)
        setup-bike-lane-preference entry-label
        set new-bike self
      ]
      create-ghost-bikes 1 [
        setup-ghost-vehicle vx vy vh exit-list "bike" new-bike
        set new-ghost self
      ]
      ask new-bike [ set my-ghost new-ghost ]
      set pending-bikes pending-bikes - 1
    ]
  ]
end

to setup-vehicle [vx vy vh exit-list vType]
  setxy vx vy
  set heading vh
  set destination-point exit-list
  set start-tick ticks
  set finished? false
  ifelse vType = "car" [
    set shape "cars"
    set color red
    set size 1
    set speed 0.083 + random-float (0.139 - 0.083)
    set mood 0
  ] [
    set shape "bike"
    set color blue
    set size 0.8
    set speed 0.041 + random-float (0.056 - 0.041)
    set preferred-lane-type "road"
    set mood 0
  ]
end

to setup-ghost-vehicle [vx vy vh exit-list vType real-agent]
  setup-vehicle vx vy vh exit-list vType
  set my-real-agent real-agent
  set speed [speed] of my-real-agent
  set hidden? true
end

to setup-bike-lane-preference [entry-label]
  foreach lane-pairs [pair ->
    if entry-label = (item 0 pair) [
      if random 100 < bike-lane-preference [
        let bike-lane-entry-label item 1 pair
        let bike-lane-route first filter [a-route -> item 0 a-route = bike-lane-entry-label] route-pairs
        let new-route-name (word (item 0 bike-lane-route) "->" (item 1 bike-lane-route))
        if is-route-active? new-route-name [
          let bike-lane-entry get-entry-point bike-lane-entry-label
          let bike-lane-x item 1 bike-lane-entry
          let bike-lane-y item 2 bike-lane-entry
          let bike-lane-exit-label item 1 bike-lane-route
          let bike-lane-exit get-exit-point bike-lane-exit-label
          set preferred-lane-type "bike-lane"
          setxy bike-lane-x bike-lane-y
          set destination-point bike-lane-exit
          set my-path new-route-name
        ]
      ]
      stop
    ]
  ]
end

;------------ MOVEMENT PROCEDURE -----;
to move-real-agents
  ask turtles with [[breed] of self = cars or [breed] of self = bikes] [
    if not finished? [
      let dest-x item 1 destination-point
      let dest-y item 2 destination-point

      if patch-here = patch dest-x dest-y [
        set travel-time (ticks - start-tick)
        set finished? true
        set speed 0

        if my-ghost != nobody and [finished?] of my-ghost [
          let real-time travel-time
          let ideal-time [travel-time] of my-ghost
          let efficiency-score 0
          if ideal-time > 0 [ set efficiency-score ideal-time / real-time ]
          let frustration-rate 0
          if travel-time > 0 [ set frustration-rate (mood / travel-time) ]
          let comfort-score efficiency-score + (frustration-rate * frustration-weight)

          set comfort-scores lput (list my-path (word breed) comfort-score) comfort-scores
          set efficiency-scores lput (list my-path (word breed) efficiency-score) efficiency-scores
          set frustration-scores lput (list my-path (word breed) frustration-rate) frustration-scores

          let agent-name (word (word breed) " " who)
          print (word agent-name " finished with a " (precision comfort-score 2) " comfort score (Time Efficiency: " (precision efficiency-score 2) ", Frustration: " (precision (frustration-rate * -1) 2) ")")
          ask my-ghost [ die ]
          die
        ]
      ]

      if not finished? [
        if breed = bikes and [meaning] of patch-here = "road" [
          let patch-behind patch-at-heading-and-distance (heading + 180) 1
          if patch-behind != nobody and any? cars-on patch-behind [
            set mood mood - 1
          ]
        ]
        let np patch-ahead 1
        let path-is-clear? false
        if np != nobody [
          ifelse ([bike-priority?] of np) [
            if not any? bikes-on np [ set path-is-clear? true ]
          ] [
            if not any? cars-on np and not any? bikes-on np [ set path-is-clear? true ]
          ]
        ]
        ifelse path-is-clear? [
          fd speed
        ] [
          if breed = cars and np != nobody and any? bikes-on np [
            let patch-above patch (pxcor) (pycor + 1)
            ifelse (patch-above != nobody and [meaning] of patch-above = "bike-lane") [
              set mood mood - 5
            ] [
              set mood mood - 1
            ]
          ]
        ]
      ]
    ]
  ]
end

to move-ghost-agents
  ; *** CRITICAL FIX: Simplified Ghost Logic ***
  ; The ghost's ONLY job is to move unimpeded and record its time.
  ; It does not calculate scores or kill other agents. This prevents the race condition.
  ask turtles with [[breed] of self = ghost-cars or [breed] of self = ghost-bikes] [
    if not finished? [
      let dest-x item 1 destination-point
      let dest-y item 2 destination-point

      ; The ghost's movement logic must match the real agent's arrival condition.
      ; It doesn't check for other agents, so its path is always clear.
      fd speed

      ; Check if the ghost has arrived at its destination patch.
      if patch-here = patch dest-x dest-y [
        set travel-time (ticks - start-tick)
        set finished? true
        set speed 0 ; Stop moving
      ]
    ]
  ]
end


;------------ MAIN RUNTIME -----;
to go
  if (pending-cars <= 0 and pending-bikes <= 0) and (count cars = 0 and count bikes = 0) [
    stop
  ]

  if pending-cars > 0 or pending-bikes > 0 [
    let available-routes []
    if route-AB-active? [ set available-routes lput ["A" "B"] available-routes ]
    if route-CD-active? [ set available-routes lput ["C" "D"] available-routes ]
    if route-EF-active? [ set available-routes lput ["E" "F"] available-routes ]
    if route-GH-active? [ set available-routes lput ["G" "H"] available-routes ]
    if route-IJ-active? [ set available-routes lput ["I" "J"] available-routes ]
    if not empty? available-routes [
      let pair one-of available-routes
      spawn-vehicle-at-entry item 0 pair item 1 pair
    ]
  ]

  move-real-agents
  move-ghost-agents

  tick
end

;:::::::::::::::::::::::::::::::;
;       DEBUGGING TOOLS         ;
;:::::::::::::::::::::::::::::::;
to show-road-directions
  ask patches with [meaning = "road"] [ set plabel lane-direction ]
end

to show-bike-lane-directions
  ask patches with [meaning = "bike-lane"] [ set plabel bike-lane-direction ]
end

to show-all-meanings
  ask patches [ set plabel meaning ]
end

to clear-patch-labels
  ask patches [ set plabel "" ]
end

to show-road-direction-arrows
  ask patches with [meaning = "road"] [
    if lane-direction = "E-W" [ set plabel "←" ]
    if lane-direction = "W-E" [ set plabel "→" ]
    if lane-direction = "N-S" [ set plabel "↓" ]
    if lane-direction = "S-N" [ set plabel "↑" ]
    if lane-direction = "" [ set plabel "" ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
254
57
922
726
-1
-1
20.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
11
10
74
43
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
81
10
144
43
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
12
52
184
85
pending-cars
pending-cars
0
50
0.0
1
1
NIL
HORIZONTAL

SLIDER
12
84
184
117
pending-bikes
pending-bikes
0
50
0.0
1
1
NIL
HORIZONTAL

SLIDER
12
117
184
150
bike-lane-preference
bike-lane-preference
0
100
64.0
1
1
percent
HORIZONTAL

MONITOR
14
258
196
303
Global Average Comfort Score
report-metrics-global-overall
17
1
11

MONITOR
14
303
195
348
Global Comfort (Cars)
report-metrics-global-for-breed \"cars\"
17
1
11

MONITOR
14
438
103
483
Active Agents
count turtles with \n[breed = cars or breed = bikes]
17
1
11

MONITOR
255
449
328
482
Comfort C->D
report-metrics-for-route-overall \"C->D\"
17
1
8

TEXTBOX
132
469
250
534
Road with a bike lane\nbike lane E to F \nRoad C to D\n
12
52.0
1

TEXTBOX
927
540
1077
558
Road A to B\n
12
2.0
1

MONITOR
851
562
922
595
Confort A->B
report-metrics-for-route-overall \"A->B\"
17
1
8

MONITOR
782
562
852
595
Cars
report-metrics-for-breed \"A->B\" \"cars\"
17
1
8

MONITOR
288
663
359
696
Cars
report-metrics-for-breed \"G->H\" \"cars\"
17
1
8

MONITOR
517
92
590
125
Cars
report-metrics-for-breed \"I->J\" \"cars\"
17
1
8

MONITOR
517
61
590
94
Confort I->J
report-metrics-for-route-overall\"I->J\"
17
1
8

MONITOR
288
693
359
726
Confort G->H
report-metrics-for-route-overall \"G->H\"
17
1
8

TEXTBOX
381
575
399
702
R\no\na\nd\n\nG \n\nto \n\nH\n
10
0.0
1

TEXTBOX
487
65
502
195
R\no\na\nd\n\nI\n\nto \n\nJ\n
10
0.0
1

TEXTBOX
424
12
740
43
A confort journey simulation
25
23.0
1

TEXTBOX
14
230
164
252
Global metrics
18
130.0
1

SLIDER
12
176
126
209
frustration-weight
frustration-weight
0
2
1.0
0.1
1
weight
HORIZONTAL

MONITOR
327
449
405
482
Cars
report-metrics-for-breed \"C->D\" \"cars\"
17
1
8

MONITOR
403
449
476
482
Bikes
report-metrics-for-breed \"C->D\" \"bikes\"
17
1
8

MONITOR
254
416
359
449
Confort bike lane 
report-metrics-for-route-overall \"C->D\"
17
1
8

MONITOR
517
125
590
158
Bikes
report-metrics-for-breed \"I->J\" \"bikes\"
17
1
8

MONITOR
288
631
359
664
Bikes
report-metrics-for-breed \"G->H\" \"bikes\"
17
1
8

MONITOR
714
562
784
595
Bikes
report-metrics-for-breed \"A->B\" \"bikes\"
17
1
8

TEXTBOX
813
237
890
259
PARKING
18
6.0
1

MONITOR
14
348
195
393
Global Comfort (Bikes)
report-metrics-global-for-breed \"bikes\"
17
1
11

SWITCH
117
530
257
563
route-AB-active?
route-AB-active?
0
1
-1000

SWITCH
920
502
1061
535
route-CD-active?
route-CD-active?
0
1
-1000

SWITCH
920
470
1059
503
route-EF-active?
route-EF-active?
0
1
-1000

SWITCH
254
25
394
58
route-GH-active?
route-GH-active?
0
1
-1000

SWITCH
518
725
652
758
route-IJ-active?
route-IJ-active?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

This model simulates urban traffic on a fixed city map to compare the travel experience of cars and bicycles. It is designed to explore the impact of infrastructure, specifically bike lanes, on agent travel time and a unique "comfort" score that accounts for traffic-induced frustration.

  

## HOW IT WORKS

### REALISTIC TRAFFIC

To model a "realistic" traffic flow, the model assigns each agent a random, fixed destination upon creation. This version is built like a "Manhattan-style" grid where agents do not turn; they follow their assigned path from start to finish.

This is managed by a paired entry/exit system. Agents spawn at specific coordinates and are given a route to follow. The entry and exit points are defined in a list with a 5-item structure:

```
["Label" x-coordinate y-coordinate heading "vehicle-type"]
```

The spawning procedure reads from this list to set an agent's starting location, its direction of travel, and what type of vehicle it is. The core emergent behavior of the model is the comfort-score, which arises from the interactions between these agents.


## HOW TO USE IT

Press the Setup button to clear the world and draw the city map.
Use the sliders to set the initial conditions for the simulation:

- pending-cars and pending-bikes: The number of cars and bikes you want to spawn during the simulation run.

- bike-lane-preference: A percentage chance that a newly spawned bike will try to switch to a dedicated bike lane if one is available nearby. [see Bike lane preference in NETLOGO FEATURES]

- frustration-weight: Controls how much the frustration-rate impacts the final comfort-score. A higher value means frustration has a bigger penalty.

- Use the switches to enable or disable specific routes. This allows you to analyze how closing one road impacts traffic on the others

- Press the go button to start the simulation. The model will run until all pending agents have been created and have completed their journeys. The Active Agents monitor tracks the current number of cars and bikes on the map. The simulation ends when the pending agents and active agents both reach zero.

Observe the results in the monitors. The dashboard features both global monitors for the entire system and route-specific monitors for each path. These are located near the end of each road on the map and display the Comfort Score (and its components, Efficiency and Frustration) for "All," "Cars," and "Bikes" on that specific route.

## THINGS TO NOTICE

#### Car Frustration:

Watch what happens when a car gets stuck behind a bike on a road without a bike lane. You can right-click the car and select "inspect" to see its mood variable decrease over time. Notice how this frustration is even higher if there is an available bike lane that the cyclist is not using.

#### The Bike Lane Effect: 
Turn the route-EF-active? switch (the dedicated bike lane) ON and OFF. Observe how this affects the "Comfort C->D (Cars)" monitor. Does providing a bike lane improve the comfort of drivers on the adjacent road?

#### Efficiency vs. Reality: 
At the start of the simulation, agents will have a high efficiency-score because the roads are empty. As you add more agents with the sliders, notice how the efficiency-score drops. This represents the time lost due to traffic congestion compared to the "ideal" travel time of the ghost agents.



## THINGS TO TRY

There is several way to look at the confort score : 

### Infrastructures impacts
Active or desactive a road : one possible usecase for an extention of this model is to help to create a confort traffic map and study how the creation of a bike lane could help : thus users could try switch OFF or ON the bike lane E->F to see how it impact the confort on the road. Using the differents switch could lead to several configurations.

### Traffic jam
pending more or less bikers or drivers could introduce different confort scores and one could notice that a road with a bike lane brings better results as the ones without. 
But this behavior is not guarantee : it also depend of the preference of the bikers, if some are not confortable on bike lane ( we could think of bikers that wanna go faster or in a future imporvement of the model if pedestrian involved stress to the bikers) 


### Nerfs of the drivers : 
We coudl simulate a big frustration on the car mood playing with the frustration weight slider : one way to see it well is to just open the "E->F" and "C->D" road, and choose a biker preference : drivers are feel frustation if block by a bike on the road but they are upset if the bike could used a bike lane available next to them (-5 per ticks)
This behavior could be observed while inspecting a car block by a bike on the road.


 

## EXTENDING THE MODEL

As the aim of the model is to help improving the traffic confort, several improvement could be done to get better insights : 

### More structural configurations : 
Model will benefit far to allow more possibilites : add bike lanes on some routes and give the choice for a bike to choose a faster and confortable route ( as for the car)
However, as some part of the map already introduce other routes, this model is limited by the fact that agent could only go in one direction and cant turn.

We could think of implement algorithm from *The Braess Paradox* [1] : Best Known with Random Deviation or Empirical Analytical.
 
### Additional behavior :
We could look at the *Traffic 2 Lanes* [2] model to allow cars or bikes to try to change lane, as this model use max-patience slider, the mood could be used to let bike try to pass a car, on the road, or on pedestrian lane.
 



## NETLOGO FEATURES

### Metric
The model's main output is the comfort-score, which is calculated for each agent upon finishing its journey. It is a combination of three sub-metrics:

#### Efficiency Score: This is a ratio of the agent's "ideal" travel time (measured by its ghost) to its actual travel time. A score of 1.0 is perfect efficiency (no delays), while a lower score indicates time lost to traffic.
efficiency-score = ideal-time / real-time

#### Frustration Rate: This measures how much an agent's mood decreased over the course of its trip. A short, very frustrating trip can have a higher frustration rate than a long, slightly annoying one.
frustration-rate = final-mood / travel-time

#### Comfort Score: This combines the two previous metrics. It starts with the efficiency and then applies a penalty based on the frustration, adjusted by the frustration-weight slider.
comfort-score = efficiency-score + (frustration-rate * frustration-weight)

### Design concept : 

#### Dashed lines :
The procedure for drawing dashed lines, such as `draw-dash-line-horizontal`, is adapted from the *4Way-Junction-Traffic-Simulation-SriLanka* [3] model. This method uses temporary turtles as "dash painters" to create dynamic road markings, which prevents the visual artifacts that can occur with static patch-based lines and allows the centerlines to terminate correctly at intersections.

```
to draw-line [coord direction line-color gap len]
  ; We use a temporary turtle to draw the line:
  ; - with a gap of zero, we get a continuous line;
  ; - with a gap greater than zero, we get a dashed line.
  create-turtles 1 [
    if direction = 90 or direction = 270 [
      setxy (min-pxcor - 0.5) coord
    ]
    if direction = 0 or direction = 180 [
      setxy coord (min-pycor - 0.5)
    ]
    hide-turtle
    set color line-color
    set heading direction
    let steps len
    while [steps > 0] [
      pen-up
      forward gap
      pen-down
      forward (1 - gap)
      set steps steps - 1
    ]
    die
  ]

end
```


### The Spawning Process and World Logic

#### Agent Initialization and Routing
In order to simulate a 'realistic' traffic flow, each agent must be created with a specific origin and destination. A key design choice in this first iteration of the model is that agents follow a fixed trajectory without turning. In other words, agents spawn at an entry point and follow the direction of that road from beginning to end.

To achieve this, the model's logic is built on a system of predefined entry points, exit points, and the routes that connect them.

#### The Route System
The define-entry-and-exit-points procedure establishes the start and end points for all possible journeys. Each point is structured as a list containing the following critical information:

Label: A unique identifier (e.g., "A", "B") used to structure the code and link points together. This avoids repeating coordinates and makes the route logic easier to read.

Coordinates: The x and y coordinates of the patch where the agent will spawn or despawn.

Heading: The direction the agent should face upon creation to ensure it moves correctly along the road (e.g., a heading of 90 degrees for west-to-east travel).

Allowed Vehicle Types: A string that defines which agents can use this point ("car", "bike", or "car/bike"). This prevents cars from spawning in dedicated bike lanes while allowing bikes the flexibility to spawn on either roads or bike lanes.

These points are then linked into route-pairs (e.g., ["A" "B"]), which formally define the start and end of a valid trajectory for an agent.

#### The Spawning Procedure
The core procedure for creating new agents is spawn-vehicle-at-entry. The total number of agents created during a simulation run is controlled by the pending-cars and pending-bikes sliders, which are decremented each time a new agent is successfully created. This is a key parameterized feature, as the "comfort" on the road seems to be correlated with the number of agents.

#### Randomized Route Assignment

One of the key ideas of the model is to measure agent comfort regardless of the specific route assigned. To achieve an unbiased result, the assignment of routes must be random.

This randomization is handled by the one-of primitive inside the go procedure. Before spawning an agent, the model builds a list of all currently active routes (based on the interface switches) and then uses one-of to select a single route from that list. This method implements an identical and independent distribution, ensuring that each available route has an equal chance of being assigned to the new agent.



### Entry/Exit Point Data Structure
The model's define-entry-and-exit-points procedure establishes the list of all possible starting (entry-points) and ending (exit-points) locations for agents. Each point in these lists is itself a list with a consistent five-part structure:

["Label" x-coordinate y-coordinate heading "vehicle-type"]

Example: ["A" -16 -8 90 "car/bike"]

The purpose of each element is as follows:

Label: A string (e.g., "A") used to structure and clarify the code in other procedure blocks. For instance, to avoid repeating the coordinates [-16 -8], the label "A" is used throughout the model.

Coordinates: The x and y coordinates of the patch where the agent will appear or disappear.

Heading: This number dictates the direction the agent should face upon creation. For example, a spawned agent at point "A" will head to 90° to match a west-to-east direction.

Vehicle Type: A string ("car", "bike", or "car/bike") that defines which kinds of agents can spawn on that entry patch. This prevents cars from spawning in bike lanes while giving bikes the flexibility to start on either roads or dedicated bike lanes.


### Bike lane preference
To create a more realistic simulation, the model includes a mechanism for cyclists to choose between using a dedicated bike lane and the main road. This design reflects real-world behavior where, even if a bike lane is available, some cyclists might prefer the road. This could happen for various reasons, such as the bike lane being obstructed or a desire to travel faster than the bike lane allows (though these specific behaviors are not yet implemented).

This choice is controlled by the bike-lane-preference slider in the interface and is implemented in the setup-bike-lane-preference procedure. This procedure is called immediately after a bike agent is created. If a randomly generated number is less than the slider's value, the model will attempt to switch the bike to a nearby bike lane. For example, if the slider is set to 100%, every bike that spawns on a road with an adjacent, active bike lane will be rerouted onto it.

To enable this logic, the model uses a list of lane-pairs which explicitly links a road entry point to a nearby bike lane entry point.
```
to define-lane-pairs
  ;-> link a road entry to a bike lane entry
  set lane-pairs [
    ["C" "E"]
    ;-> As the vertical main road (with a bike lane on each side) is not used, this is the only pair,
    ; but if new entries match, we could add new lane-pairs in this list.
   ]
end
```
This mechanism ensure that the bike spawning process is not purely random but is influenced by both infrastructure availability and a probabilistic element of rider preference.


### Ghost mechanism

#### Ghost functionality :
Every agent (cars or bikes) as a corresponding 'ghost' turtle will execute the ideal travel time, that is to say the same traject without any obstacles.

#### Ghost creation 
When an agent is created during the `spawn-vehicule-at-entry` procedure, a ghost agent is also created.
These 2 agents will be paired/linked and will share the same parameters : same vehicule, speed, behavior, and the same road to travel.
This is the core idea of the ghost functionality : to measure effectively the perfect time, the real agent and its ghost should have the same setup. 
The `hidden?` built-in variable is very usefull to create these ghost as it allows to hide the ghost turtle. 



#### Ghost movement
As ghost should perform a perfect time without constraints/obstacles, ghost movement ommit to specify rules as `if np != nobody` or `if not any?` implemented in the real agent movement procedure to dont go forward if there is an agent ahead. 


#### Platonic ideal
To measure the efficiency of an agent's journey, the model needs a baseline for comparison, or an "ideal" travel time. I decided to reject a simplistic definition, like an instantaneous trip from point A to point B, because such a measurement would be physically unrealistic and provide little insight.

Instead, the model is designed around a more realistic concept: the ghost agent represents the travel time of a perfectly law-abiding driver on an empty road. This means the ghost is not free from all constraints; it must follow the "laws" of the simulated world.

In the current version, the model's world is simple, containing no complex traffic signals or priority rules. Therefore, the only "laws" the ghost agent must obey are fundamental: it must follow the same path and move at the same speed defined by its real agent. It is essentially unimpeded by other traffic.

This design choice makes the model's efficiency metric robust and scalable. As the model evolves to include more complex constraints—such as traffic lights or stop signs—these new rules must be implemented for both the real agents and their ghost counterparts. By doing this, the "ideal time" will always remain a fair and realistic comparison, ensuring the efficiency score is a meaningful measure.


## RELATED MODELS

*The development of this model was supported by the generative AI tool Perplexity. To provide transparency on this collaborative process, the following section details a key design decision :* 

### Collaborative Development Process
This model was developed with the assistance of the AI language model Perplexity [4] . The AI was used as a tool for brainstorming, debugging, code generation, and documentation refinement. The following is a representative example of the iterative process used to develop the ghost agent's movement logic.

#### The Initial Concept

My initial idea for the ghost agent was inspired by the "ghost runner" feature on sports watches, where you can race against a recording of your previous best time. The goal was to create a "perfect" run for each agent's assigned route.

#### The AI's First Proposal

Based on this concept, Perplexity suggested a block of code for the ghost's arrival check that was different from the real agent's. The core of its logic was:
```
text
if distance patch dest-x dest-y < speed [
  set travel-time (ticks - start-tick)
  set finished? true
]
```
The AI explained its reasoning for this more complex code, which I summarized in my notes:

"The Real Agent's Job: To navigate a discrete, grid-based world... It needs grid precision. The Ghost Agent's Job: To measure the 'platonic ideal' of travel time... It needs continuous accuracy."

#### The Critical Review and Design Decision

While I understood the AI's logic, I critically evaluated it in the context of my specific model. I concluded that this approach, while clever, was overly complex for the current iteration. My reasoning was:

"I think as my model dont had constraints for the moment (no red,green light, no stop, no rules...)... it will not be implemented because not needed."

I realized that having two different movement and arrival logics would make the model harder to debug and maintain. The "continuous accuracy" was an unnecessary feature for a model where all movement happens on a discrete grid of patches.

#### The Final, User-Driven Implementation

I decided on a simpler, more robust approach. The ghost would mimic the real agent's movement exactly (fd speed), but with one key difference: it would be "blind" to other agents and its path would always be considered clear. This design perfectly captured the concept of an "unimpeded driver" without adding unnecessary code complexity.

This example illustrates the working relationship: the AI provided technical options and rationales, while I, as the model designer, provided the project context, made the final design decisions, and ensured the implementation remained aligned with the model's core goals.

### Netlogo Models :
 
- *"Traffic Basic": a simple model of the movement of cars on a highway.*
- *"Traffic Basic Utility": a version of "Traffic Basic" including a utility function for the cars.*
- *"Traffic Basic Adaptive": a version of "Traffic Basic" where cars adapt their acceleration to try and maintain a smooth flow of traffic.*
- *"Traffic Basic Adaptive Individuals": a version of "Traffic Basic Adaptive" where each car adapts individually, instead of all cars adapting in unison.*
- *"Traffic Intersection": a model of cars traveling through a single intersection.*
- *"4Way-Junction-Traffic-Simulation-SriLanka model"* [4]

## CREDITS AND REFERENCES


### Citation : 
[1] Rasmussen, L. and Wilensky, U. (2019). NetLogo Braess Paradox model. http://ccl.northwestern.edu/netlogo/models/BraessParadox. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.


[2] Wilensky, U. & Payette, N. (1998). NetLogo Traffic 2 Lanes model. http://ccl.northwestern.edu/netlogo/models/Traffic2Lanes. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

### Credits :
[3] Anonymous. (n.d.). 4Way-Junction-Traffic-Simulation-SriLanka model. NetLogo Community Models. https://ccl.northwestern.edu/netlogo/models/community/4Way-Junction-Traffic-Simulation-SriLanka

[4] Perplexity. (2025). Perplexity (Gemini 2.5 Pro model) [Large language model]. https://www.perplexity.ai

@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bike
true
0
Polygon -7500403 true true 75 90 75 105
Polygon -16777216 true false 225 150
Rectangle -16777216 true false 136 101 165 148
Rectangle -16777216 true false 136 180 165 227
Rectangle -7500403 true true 143 91 158 241
Polygon -13345367 true false 120 165 135 180 165 180 180 165 165 150 135 150 120 165
Polygon -13345367 true false 135 165 127 119 140 150
Polygon -13345367 true false 162 153 172 120 169 154
Polygon -7500403 true true 118 128 141 110 158 109 182 125 179 129 154 112 144 113 120 132 118 130
Circle -16777216 false false 134 151 30
Rectangle -16777216 true false 146 194 155 233

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
true
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

cars
true
0
Rectangle -7500403 true true 90 75 210 240
Polygon -7500403 true true 90 75 90 60 105 45 195 45 210 60 210 75
Polygon -7500403 true true 90 240 105 255 195 255 210 240
Polygon -16777216 true false 120 75 180 75 195 120 105 120 120 75
Line -16777216 false 105 120 105 165
Line -16777216 false 105 180 105 225
Line -16777216 false 195 120 195 165
Line -16777216 false 195 180 195 225
Polygon -16777216 true false 105 225 195 225 180 240 120 240 105 225
Circle -16777216 true false 204 80 49
Circle -16777216 true false 49 80 49
Circle -16777216 true false 47 188 49
Circle -16777216 true false 203 186 49

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fat-line
true
0
Rectangle -1 true false 0 0 300 45
Rectangle -1 true false 0 120 300 165
Rectangle -1 true false 0 255 300 300

fat-line-bike
false
15
Rectangle -1 true true 0 0 300 45
Rectangle -1 true true 0 120 300 165
Rectangle -1 true true 0 255 300 300

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

road-dash
true
0
Rectangle -1 true false 15 120 285 165

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
