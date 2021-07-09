extensions [csv]
; modified from the patch choice model from optimal foraging theory
; (Michael Barton, Arizona State University)
; by Isaac Ullah and Miriam Coleman-Kopels, San Diego State University

breed [foragers forager]
breed [animals animal]

foragers-own [energy diet-breadth]
animals-own [energy age species payoff rank time-since-repro]
patches-own [ptimer desert]
globals [prey-list long-prey-list diversity _recording-save-file-name birth-count death-count num-foragers males-killed females-killed ppfem-killed]

to Setup
  clear-all
  Setup_Animals
  Setup_Foragers
  Setup_Patches
  set males-killed 0
  set females-killed 0
  set ppfem-killed 0
  set num-foragers count foragers
  file-open Output-csv-file
  file-print csv:to-row [ "Males Taken" "Females Taken" "Post Partum Femals Taken" "Forager Energy" "Number Males" "Number Females" "Buffalo Energy" "Buffalo Births" "Buffalo Deaths" "Proportion Ungrazed" ]
  reset-ticks
end

to Go
  if init-foragers != 0 [
    if not any? foragers [stop]
  ]
  if not any? animals [stop]
  if ( stop-at-max-ticks = true ) and ticks >= max-ticks [stop]

  ask foragers [
    Move
    set energy energy - foragers-movement-cost
    Forage
    Calculate-Diversity
    if imortal-foragers = false [
      Check-Death
      ]
    ]

  ask animals [
    Move-animals
    set energy energy - animals-movement-cost ; animals consume energy to move
    set age age + 1 ; animals get older
    if [species] of self = 2 [ ; am I female?
      set time-since-repro time-since-repro + 1 ; advance the reproduction clock
    ]
    ifelse stop-at-max-herd-size = false [ ; check to see if mating is allowed currently, mate if so
      mate ]
      [
      if count animals < max-herd-size [
        mate ]
    ]
    if grass-growth = true [
      eat-grass ; buffalo graze grass down in this version
    ]
    Check-Animal-Death ; buffalo will die when out of energy, perhaps if they are below starvation threshold, or if they are too old
    if [species] of self = 2 and [time-since-repro] of self = birth-spacing [ ; ween offspring (spawn and separate)
      ween
    ]
    ]

  if grass-growth = true [ ask patches [ grow-grass ] ]

  Do_Plots
  output-data
  tick
end

to Setup_Patches
  ask patches [ set pcolor green ]
  if grass-growth = true [ ask up-to-n-of ( ( count patches ) * (1 - grass-proportion ) ) patches [ set pcolor brown ] ] ; if variable grass, set patches up
  ask patches [
    ifelse pcolor = green
      [ set ptimer 0 ] ; set timer to fully regrown
      [ set ptimer random grass-regrowth-time ] ; initialize grass regrowth clocks randomly for brown patches
  ]
  if aridification = true [
    ask patches [ if pcolor = brown [ set desert true ] ] ; if desertification is on, inital brown patches will stay brown
  ]
end

to Setup_Foragers
  create-foragers init-foragers
    [
    set shape "hunter2"
    set size 3
    set color 38
    set energy 100 ;; ENHANCEMENT: make this a slider
    set prey-list [] ; rolling list of prey species taken
    set long-prey-list [] ; a longer list for all kills
    ]
  ask foragers [setxy random-xcor random-ycor] ; place the foragers randomly in the world
end

to Setup_Animals
  ; Create 2 animal species with different processing costs, food values, birth rates, and initial population densities

  let number-of-males round (init-prey * male-female-starting-proportion / 100)
  let number-of-females round (init-prey * (100 - male-female-starting-proportion) / 100 )

  set birth-count 0
  set death-count 0

  create-animals number-of-males [ ; These are Males
    setxy 0.5 * max-pxcor 0.5 * max-pycor
    set species 1
    set energy lifespan-animals
    set age 0
    set shape "cow"
    set size 2.5
    set color cyan
    set payoff ( food-value-males - processing-cost-males ) ; find payoff of food value minus processing costs
    ifelse payoff >= ( food-value-females - processing-cost-females ) ; set rank of prey
      [ set rank 1 ]
      [ set rank 2 ]
    ]

  create-animals number-of-females [ ; These are Females
    setxy 0.5 * max-pxcor 0.5 * max-pycor
    set species 2
    set energy lifespan-animals
    set age 0
    set time-since-repro 0 ; only females get this
    set shape "cow"
    set size 2
    set color pink
    set payoff ( food-value-females - processing-cost-females ) ; find payoff of food value minus processing costs
    ifelse payoff >= ( food-value-males - processing-cost-males ) ; set rank of prey
      [ set rank 1 ]
      [ set rank 2 ]
    ]

   ask animals [ ; initial setup to minimize "burn in" time of model runs
    fd (random (0.25 * max-pxcor)) ; move the animals into a loose cluster
    set heading mean-heading [ heading ] of animals in-radius (0.25 * max-pxcor) ; get them facing the same way as neighbors
    set age random lifespan-animals ; create an initial age distribution
  ]

 ; ask animals [setxy random-xcor random-ycor set age random lifespan-animals] ; place the animals randomly in the world and make them all ages

end

to mate
  let mates one-of animals-on neighbors ; pick a random nearby animal
  if mates != nobody  [    ; did we get someone?
    if ([species] of mates = 1) and ([species] of self = 2) and ([time-since-repro] of self >= birth-spacing) [ ; am I female? Did I meet a male? and has it been long enough?
        if random-float 100 <= reproduction-animals [  ; throw "dice" to see if I will reproduce
        set birth-count birth-count + 1
        set time-since-repro 0
        ]
      ]
  ]
end

to ween
  hatch 1 [
    ifelse random 100 <= 50 [
      set species 1 ; spawn a male and give it some male attributes
      set shape "cow"
      set size 2.5
      set color cyan
      set payoff ( food-value-males - processing-cost-males ) ; find payoff of food value minus processing costs
      ifelse payoff >= ( food-value-females - processing-cost-females ) ; set rank of prey
        [ set rank 1 ]
        [ set rank 2 ]
      set energy lifespan-animals
      set age 0
    ]
    [ set species 2 ; spawn a female and give it some female attributes
      set shape "cow"
      set size 2
      set color pink
      set payoff ( food-value-females - processing-cost-females ) ; find payoff of food value minus processing costs
      ifelse payoff >= ( food-value-males - processing-cost-males ) ; set rank of prey
        [ set rank 1 ]
        [ set rank 2 ]
      set energy lifespan-animals
      set age 0
      set time-since-repro 0 ; only females get this
    ]
  ]
end

to Move
  let target min-one-of (animals in-radius foraging-radius) with [rank = 1] [distance myself] ; closest high-rank prey in radius
  let alt-target min-one-of (animals in-radius foraging-radius) with [species = 2 and time-since-repro <= birth-spacing] [distance myself] ; closest post partum female
  ifelse target != nobody and alt-target != nobody [ ;are there both kinds of prey?
    ifelse [payoff] of alt-target + food-value-calf > [payoff] of target [ ;pp female value is higher
      face alt-target
      fd 1 ] [
      face target
      fd 1
    ]
  ] [
  ifelse target != nobody  [
    face target
    fd 1
  ] [
    rt random 45
    lt random 45 ; otherwise do a random walk
    fd 1
  ] ]
end

to Move-animals
  let target-patch min-one-of (patches in-radius 3 with [pcolor = green]) [distance myself] ; First, look for nearby grass...
  ifelse target-patch != nobody  [
    face target-patch ; if so, then move towards it...
    fd 1
  ] [
    let target-anims (animals in-radius 5); ...if not, then look for any nearby buffalo...
    ifelse target-anims != nobody  [
      set heading mean-heading [ heading ] of target-anims ; ... if so, then face the average way your herd neighbors are facing...
      fd 1
    ] [ set heading random 360 fd 1 ] ; ...if not, then do a random walk.
  ]
end

to-report mean-heading [ headings ]
  let mean-x mean map sin headings
  let mean-y mean map cos headings
  report atan mean-x mean-y
end

to Forage
  let prey one-of animals-here  ;; encounter a random nearby animal
  let other-prey animals with [rank = 1] in-radius foraging-radius ;; give forager knowledge ofhigh-ranked animals within set distance
  let alternative-payoff 0
  if count other-prey != 0 [
    set alternative-payoff (mean [payoff] of other-prey) - ( (count patches in-radius foraging-radius / count other-prey ) * foragers-movement-cost)
  ]
  if prey != nobody  [ ;; did we get one?  If so,
    let current-payoff 0  ;; current payoff of encountered animal
    ifelse [species] of prey = 2 and [time-since-repro] of prey <= birth-spacing
      [ set current-payoff [payoff] of prey + food-value-calf ]  ;; if prey is female and recently calved, add food value for calf with mother
      [ set current-payoff [payoff] of prey ];; males and other femals get assigned payoff
    if (current-payoff >= alternative-payoff) or  ;; only pursue prey with payoff greater than continued search,
       (energy < forager-starvation-thresh)  ; forager is starving and pursues whatever prey is encountered
        [ set energy energy + current-payoff  ;; get energy from eating animal
          set prey-list fput ([species] of prey) prey-list ; add prey-species to running list of prey taken
          set long-prey-list fput ([species] of prey) long-prey-list ; add prey-species to running list of prey taken
          if [species] of prey = 1 [set males-killed males-killed + 1]
          if [species] of prey = 2 [set females-killed females-killed + 1]
          if [species] of prey = 2 and [time-since-repro] of prey <= birth-spacing [
            set ppfem-killed ppfem-killed + 1 ; if a post partum female was killed, update that count.
          ]
        ]
        ask prey [ die ]                            ; kill it, and...
      ]
  while [length prey-list > 10] [set prey-list remove-item 10 prey-list] ; manage running list of prey taken
  if energy > 100 [ set energy 100 ] ;; make sure that energy does not go above maximum
end

to eat-grass  ; buffalo procedure
  ; buffalo eat grass and turn the patch brown
  if pcolor = green [
    set pcolor brown
    set energy energy + animals-gain-from-food  ; buffalo maintain energy by eating
  ]
  if energy > 100 [ set energy 100 ] ;; make sure that energy does not go above maximum
end

to grow-grass  ; patch procedure
  ; countdown on brown patches: if you reach 0, grow some grass
   if pcolor = brown [
     ifelse ptimer <= 0
       [ set pcolor green
         set ptimer grass-regrowth-time ]
       [ set ptimer ptimer - 1 ]
     if desert = true [
      set pcolor brown ; if desertification is on, then the initial brown patches stay brown
     ]
   ]

end

to-report grass
  ifelse grass-growth = true [
    report patches with [pcolor = green]
  ]
  [ report 0 ]
end

to Calculate-Diversity
  set diversity 0
  if member? 1 prey-list [set diversity diversity + 1]
  if member? 2 prey-list [set diversity diversity + 1]
end

to Do_Plots
  set-current-plot "Prey Taken"
  set-current-plot-pen "Male"
  plot males-killed
  set-current-plot-pen "Female"
  plot females-killed
  set-current-plot-pen "PP-Female"
  plot ppfem-killed
  set-current-plot "Average Energy"
  set-current-plot-pen "Foragers"
  ifelse count foragers != 0
    [plot (mean [energy] of foragers)]
    [plot 0]
  set-current-plot-pen "Animals"
  ifelse count animals != 0
    [plot (mean [energy] of animals)]
    [plot 0]
  set-current-plot "Population"
  set-current-plot-pen "Male"
  plot count animals with [species = 1]
  set-current-plot-pen "Female"
  plot count animals with [species = 2]
  set-current-plot-pen "Foragers"
  plot num-foragers
  set-current-plot "Proportion of Grazed to Ungrazed Grass"
  set-current-plot-pen "pgraze"
  plot ( ( count patches with [ pcolor = green ] ) / ( count patches ) ) * 100
end

to output-data
  file-print csv:to-row ( list
    ( num-foragers )
    ( sum [energy] of foragers )
    ( males-killed )
    ( females-killed )
    ( ppfem-killed )
    ( count animals with [species = 1] )
    ( count animals with [species = 2] )
    ( sum [energy] of animals )
    ( birth-count )
    ( death-count)
    ( ( ( count patches with [ pcolor = green ] ) / ( count patches ) ) * 100 )
      )
  file-flush
end

to Check-Death
  ask foragers [if energy <= 0 [die]]
  set num-foragers count foragers
end

to Check-Animal-Death
  ask animals [if ( energy <= 0 ) or energy <= animals-starvation-threshold and random 2 = 1 or ( age = lifespan-animals + random 10 ) or ;;  if the energy is below starvation threshold, there is a 50/50 chance of dying. Totally spent animals will always die.
    ( age = lifespan-animals - random 10) or ( age = lifespan-animals + 10 )[ ; Animals that have lived too long have an increasing chance of dying. Too old animals will always die.
      set death-count death-count + 1
      die
    ]
  ]
  ask n-of (count animals / external-mortality) animals [ ; apply a density dependent mortality curve for external predation and accidental death
    set death-count death-count + 1
    die
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
529
128
1143
653
-1
-1
6.0
1
10
1
1
1
0
1
1
1
0
100
0
85
1
1
1
ticks
30.0

BUTTON
318
132
384
165
setup
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
388
132
451
165
run
Go
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
13
28
208
61
init-foragers
init-foragers
0
100
14.0
1
1
NIL
HORIZONTAL

SLIDER
7
210
186
243
processing-cost-males
processing-cost-males
0
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
7
177
186
210
food-value-males
food-value-males
5
100
50.0
1
1
NIL
HORIZONTAL

BUTTON
458
132
521
165
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
7
251
221
284
male-female-starting-proportion
male-female-starting-proportion
0
100
50.0
1
1
%
HORIZONTAL

SLIDER
190
210
382
243
processing-cost-females
processing-cost-females
0
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
189
176
382
209
food-value-females
food-value-females
5
100
40.0
1
1
NIL
HORIZONTAL

TEXTBOX
18
154
109
184
Buffalo
12
0.0
1

SLIDER
230
251
434
284
init-prey
init-prey
0
1000
250.0
1
1
NIL
HORIZONTAL

PLOT
7
409
512
534
Prey Taken
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Male" 1.0 0 -11221820 true "" ""
"Female" 1.0 0 -3508570 true "" ""
"PP-Female" 1.0 0 -8630108 true "" ""

MONITOR
448
360
517
405
Males
length (filter [ ?1 -> ?1 = 1 ] prey-list)
0
1
11

TEXTBOX
221
101
322
119
Female Buffalo
12
0.0
1

MONITOR
447
310
516
355
Females
length (filter [ ?1 -> ?1 = 2 ] prey-list)
0
1
11

TEXTBOX
461
259
511
302
# Taken\nOver 10 \nCycles
11
0.0
1

PLOT
7
661
510
781
Average Energy
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Foragers" 1.0 0 -16777216 true "" ""
"Animals" 1.0 0 -7500403 true "" ""

SLIDER
8
292
218
325
reproduction-animals
reproduction-animals
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
7
329
219
362
lifespan-animals
lifespan-animals
0
500
300.0
1
1
NIL
HORIZONTAL

PLOT
516
661
1140
781
Population
NIL
Number
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Male" 1.0 0 -11221820 true "" ""
"Female" 1.0 0 -3508570 true "" ""
"Foragers" 1.0 0 -16777216 true "" ""

SLIDER
398
89
574
122
grass-regrowth-time
grass-regrowth-time
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
231
333
436
366
animals-gain-from-food
animals-gain-from-food
0
10
6.0
0.1
1
NIL
HORIZONTAL

SLIDER
232
371
435
404
animals-starvation-threshold
animals-starvation-threshold
0
100
25.0
1
1
NIL
HORIZONTAL

SLIDER
230
291
434
324
animals-movement-cost
animals-movement-cost
0
10
5.0
0.1
1
NIL
HORIZONTAL

SLIDER
14
65
208
98
foragers-movement-cost
foragers-movement-cost
0
5
1.0
.1
1
NIL
HORIZONTAL

PLOT
7
537
512
657
Proportion of Grazed to Ungrazed Grass
NIL
NIL
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"pgraze" 1.0 0 -14439633 true "" ""

INPUTBOX
970
10
1139
70
Output-csv-file
output.csv
1
0
String

INPUTBOX
701
10
814
70
max-herd-size
500.0
1
0
Number

INPUTBOX
840
10
946
70
max-ticks
3000.0
1
0
Number

SWITCH
675
81
849
114
stop-at-max-ticks
stop-at-max-ticks
0
1
-1000

SWITCH
859
82
1043
115
stop-at-max-herd-size
stop-at-max-herd-size
1
1
-1000

SWITCH
396
10
531
43
grass-growth
grass-growth
0
1
-1000

SLIDER
398
51
574
84
grass-proportion
grass-proportion
0
1
0.66
.01
1
NIL
HORIZONTAL

SWITCH
536
10
658
43
aridification
aridification
0
1
-1000

SLIDER
7
369
219
402
external-mortality
external-mortality
0
1000
250.0
1
1
NIL
HORIZONTAL

TEXTBOX
1054
90
1204
108
NIL
12
0.0
1

MONITOR
1053
79
1138
124
Birth count
birth-count
0
1
11

SLIDER
385
175
523
208
birth-spacing
birth-spacing
0
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
14
101
208
134
foraging-radius
foraging-radius
1
100
20.0
1
1
NIL
HORIZONTAL

TEXTBOX
63
10
213
28
Foragers
12
0.0
1

SLIDER
384
211
527
244
food-value-calf
food-value-calf
0
20
20.0
1
1
NIL
HORIZONTAL

SWITCH
216
88
391
121
imortal-foragers
imortal-foragers
1
1
-1000

SLIDER
216
49
390
82
forager-starvation-thresh
forager-starvation-thresh
0
100
25.0
1
1
NIL
HORIZONTAL

MONITOR
580
79
672
124
Death count
death-count
0
1
11

MONITOR
215
127
302
172
# Foragers
num-foragers
17
1
11

@#$#@#$#@
## OVERVIEW

This is an agent-based simulation of human hunting of a sexually-dimorphic big-game species, based on the the classic "diet breadth model" of optimal foraging theory (see Foley 1985). You can simulate the impacts of hunter choice when encoutnering a bigger, but more dangerous male animal, versus a smaller but perhaps easier to kill female (perhaps with calf).

## CREDITS AND REFERENCES

Isaac I. Ullah and Miriam Coleman, San Diego State University (2021)

Some code reused from the "Diet Breadth" model by C. Michael Barton, Arizona State University 

For an overview of OFT models, see Foley, R. (1985). Optimality theory in anthropology. Man, 20, 222-242.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

acorn
false
0
Polygon -7500403 true true 146 297 120 285 105 270 75 225 60 180 60 150 75 105 225 105 240 150 240 180 225 225 195 270 180 285 155 297
Polygon -6459832 true false 121 15 136 58 94 53 68 65 46 90 46 105 75 115 234 117 256 105 256 90 239 68 209 57 157 59 136 8
Circle -16777216 false false 223 95 18
Circle -16777216 false false 219 77 18
Circle -16777216 false false 205 88 18
Line -16777216 false 214 68 223 71
Line -16777216 false 223 72 225 78
Line -16777216 false 212 88 207 82
Line -16777216 false 206 82 195 82
Line -16777216 false 197 114 201 107
Line -16777216 false 201 106 193 97
Line -16777216 false 198 66 189 60
Line -16777216 false 176 87 180 80
Line -16777216 false 157 105 161 98
Line -16777216 false 158 65 150 56
Line -16777216 false 180 79 172 70
Line -16777216 false 193 73 197 66
Line -16777216 false 237 82 252 84
Line -16777216 false 249 86 253 97
Line -16777216 false 240 104 252 96

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bird
false
0
Polygon -7500403 true true 135 165 90 270 120 300 180 300 210 270 165 165
Rectangle -7500403 true true 120 105 180 237
Polygon -7500403 true true 135 105 120 75 105 45 121 6 167 8 207 25 257 46 180 75 165 105
Circle -16777216 true false 128 21 42
Polygon -7500403 true true 163 116 194 92 212 86 230 86 250 90 265 98 279 111 290 126 296 143 298 158 298 166 296 183 286 204 272 219 259 227 235 240 241 223 250 207 251 192 245 180 232 168 216 162 200 162 186 166 175 173 171 180
Polygon -7500403 true true 137 116 106 92 88 86 70 86 50 90 35 98 21 111 10 126 4 143 2 158 2 166 4 183 14 204 28 219 41 227 65 240 59 223 50 207 49 192 55 180 68 168 84 162 100 162 114 166 125 173 129 180

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
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

caterpillar
true
0
Polygon -7500403 true true 165 210 165 225 135 255 105 270 90 270 75 255 75 240 90 210 120 195 135 165 165 135 165 105 150 75 150 60 135 60 120 45 120 30 135 15 150 15 180 30 180 45 195 45 210 60 225 105 225 135 210 150 210 165 195 195 180 210
Line -16777216 false 135 255 90 210
Line -16777216 false 165 225 120 195
Line -16777216 false 135 165 180 210
Line -16777216 false 150 150 201 186
Line -16777216 false 165 135 210 150
Line -16777216 false 165 120 225 120
Line -16777216 false 165 106 221 90
Line -16777216 false 157 91 210 60
Line -16777216 false 150 60 180 45
Line -16777216 false 120 30 96 26
Line -16777216 false 124 0 135 15

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

hunter
false
0
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 270 135 255 165 165 105
Circle -6459832 true false 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -6459832 true false 120 90 105 90 180 195 180 165
Line -6459832 false 109 105 139 105
Line -6459832 false 122 125 151 117
Line -6459832 false 137 143 159 134
Line -6459832 false 158 179 181 158
Line -6459832 false 146 160 169 146
Rectangle -6459832 true false 120 193 180 201
Rectangle -6459832 true false 114 187 128 208
Rectangle -6459832 true false 177 187 191 208
Polygon -16777216 true false 225 30 255 75 270 120 270 150 255 195 225 240 255 210 270 195 285 150 285 120 270 75 225 30

hunter2
false
0
Rectangle -7500403 true true 142 79 187 94
Polygon -7500403 true true 30 75 135 135 150 105 45 60
Polygon -7500403 true true 210 90 270 165 255 180 180 105
Circle -7500403 true true 125 5 80
Polygon -7500403 true true 120 90 135 195 105 300 150 300 135 285 165 225 180 300 225 300 210 285 195 195 210 90
Polygon -14835848 true false 135 90 120 90 195 195 195 165
Line -6459832 false 109 105 139 105
Line -6459832 false 122 125 151 117
Line -6459832 false 137 143 159 134
Line -6459832 false 158 179 181 158
Line -6459832 false 146 160 169 146
Polygon -14835848 true false 135 180 105 240 225 240 195 180
Rectangle -16777216 true false 132 178 199 188
Rectangle -6459832 true false 5 63 228 72
Polygon -11221820 true false 192 50 285 60 211 83

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

mouse side
false
0
Polygon -7500403 true true 38 162 24 165 19 174 22 192 47 213 90 225 135 230 161 240 178 262 150 246 117 238 73 232 36 220 11 196 7 171 15 153 37 146 46 145
Polygon -7500403 true true 289 142 271 165 237 164 217 185 235 192 254 192 259 199 245 200 248 203 226 199 200 194 155 195 122 185 84 187 91 195 82 192 83 201 72 190 67 199 62 185 46 183 36 165 40 134 57 115 74 106 60 109 90 97 112 94 92 93 130 86 154 88 134 81 183 90 197 94 183 86 212 95 211 88 224 83 235 88 248 97 246 90 257 107 255 97 270 120
Polygon -16777216 true false 234 100 220 96 210 100 214 111 228 116 239 115
Circle -16777216 true false 246 117 20
Line -7500403 true 270 153 282 174
Line -7500403 true 272 153 255 173
Line -7500403 true 269 156 268 177

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

rabbit
false
0
Polygon -7500403 true true 61 150 76 180 91 195 103 214 91 240 76 255 61 270 76 270 106 255 132 209 151 210 181 210 211 240 196 255 181 255 166 247 151 255 166 270 211 270 241 255 240 210 270 225 285 165 256 135 226 105 166 90 91 105
Polygon -7500403 true true 75 164 94 104 70 82 45 89 19 104 4 149 19 164 37 162 59 153
Polygon -7500403 true true 64 98 96 87 138 26 130 15 97 36 54 86
Polygon -7500403 true true 49 89 57 47 78 4 89 20 70 88
Circle -16777216 true false 37 103 16
Line -16777216 false 44 150 104 150
Line -16777216 false 39 158 84 175
Line -16777216 false 29 159 57 195
Polygon -5825686 true false 0 150 15 165 15 150
Polygon -5825686 true false 76 90 97 47 130 32
Line -16777216 false 180 210 165 180
Line -16777216 false 165 180 180 165
Line -16777216 false 180 165 225 165
Line -16777216 false 180 210 210 240

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="SRS-Experiments" repetitions="40" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>( length (filter [ ?1 -&gt; ?1 = 1 ] prey-list) )</metric>
    <metric>( length (filter [ ?1 -&gt; ?1 = 2 ] prey-list) )</metric>
    <metric>( count animals with [species = 1] )</metric>
    <metric>( count animals with [species = 2] )</metric>
    <metric>( ( ( count patches with [ pcolor = green ] ) / ( count patches ) ) * 100 )</metric>
    <enumeratedValueSet variable="init-foragers">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="processing-cost-females">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-value-males">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;diet_breadth_buffalo_with_grass&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foragers-movement-cost">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduction-animals">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="animals-starvation-threshold">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="animals-gain-from-food">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="animals-movement-cost">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="processing-cost-males">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-herd-size">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-value-females">
      <value value="40"/>
      <value value="50"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-max-herd-size">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="male-female-proportion">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-prey">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-max-ticks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-csv-file">
      <value value="&quot;output.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lifespan-animals">
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SRS-Experiments-V2" repetitions="40" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>( length (filter [ ?1 -&gt; ?1 = 1 ] prey-list) )</metric>
    <metric>( length (filter [ ?1 -&gt; ?1 = 2 ] prey-list) )</metric>
    <metric>( count animals with [species = 1] )</metric>
    <metric>( count animals with [species = 2] )</metric>
    <enumeratedValueSet variable="init-foragers">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="processing-cost-females">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-value-males">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;diet_breadth_buffalo_with_grass&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foragers-movement-cost">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduction-animals">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="animals-starvation-threshold">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="animals-gain-from-food">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="animals-movement-cost">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="processing-cost-males">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-herd-size">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-value-females">
      <value value="30"/>
      <value value="50"/>
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-max-herd-size">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="male-female-proportion">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-prey">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at-max-ticks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Output-csv-file">
      <value value="&quot;output.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lifespan-animals">
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
