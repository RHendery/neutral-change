globals [
  links-list ;; this is the links between nodes and is imported from a file
  node-number ;; this is used to increment node-id
  listofturtles
  k
  dominant ; which variant is dominant at any given time
  shift
  ]

turtles-own [n
  node-id ;; We have to set a node-id as distinct from the who number because when we link turtles according to the link file, we have to be able to reference the turtles in the nodes file somehow.
  orig-state       ;; each person's initial variant (1 or 0 for binary variable)
  variant ;; current variant the person prefers (uses?)
  degree
  ]

to setup
  clear-all
  set shift 0
  set dominant 0 ; this might need to change later
  import-network
  distribute-grammars
  ask turtles [set degree count link-neighbors]
  repeat 10000 [ let iuseless hatch-new  ]
  repeat 300 [ layout-spring turtles links 0.2 15 1 ]
  ask turtles [set degree count link-neighbors]
;  ask turtles [ set label degree ]
  reset-ticks
end


;; Helper procedure for looking up a node by node-id.
to-report get-node [id]
  report one-of turtles with [node-id = id]
end

to randomly-wire

  let i 0
  while [i < number-of-wires]
  [
    ask one-of turtles [ create-link-with one-of other turtles ]
   set i i +  1
  ]

end

to import-network
  clear-all
  ask patches [ set pcolor 58 ]
  set-default-shape turtles "circle"
  ifelse random-nodes = FALSE
  [
    import-attributes
    set k count turtles - 1
  ]
  [
    create-turtles number-of-black-nodes [ set color black ]
    create-turtles number-of-white-nodes [ set color white ]
    set k k-connections-if-random
  ]  ;; this imports the nodes from a file
  ifelse random-wiring =  TRUE or random-nodes = TRUE [ randomly-wire ] [ import-links  ] ;; this imports the links from a file
  repeat 300 [ layout-spring turtles links 0.2 15 1 ]
end

to import-attributes
    file-open "nodes.txt"

  let node-total 0

  while [not file-at-end?]
  [
    let items read-from-string (word "[" file-read-line "]")
    crt 1 [
      set node-id item 0 items
      set color item 1 items
    ]
    set node-total node-total + 1; increment counter
  ]
  file-close

   set node-number node-total;; this is so i can increment node-ids correctly when adding people later
end



to distribute-grammars ;; this establishes the initial wordlists on the basis of color of nodes from import file.
  ask turtles [
    if color = white [set variant 1 ]
    if color = black [ set variant 0 ]
  ]

end


;; This procedure reads in a file that contains all the links
;; The file is simply 3 columns separated by spaces.  In this
;; example, the links are directed.  The first column contains
;; the node-id of the node originating the link.  The second
;; column the node-id of the node on the other end of the link.
;; The third column is the strength of the link.

to import-links
  ;; This opens the file, so we can use it.
  file-open "links.txt"
  ;; Read in all the data in the file
  while [not file-at-end?]
  [
    ;; this reads a single line into a three-item list
    let items read-from-string (word "[" file-read-line "]")
    ask get-node (item 0 items)
    [
      create-link-with get-node (item 1 items)
    ]
  ]
  file-close
end



to update-color
  if variant = 0 [set color black ]
  if variant = 1 [set color white ]
end



;;;
;;; GO PROCEDURES
;;;

to go

  let previous-dominance dominant ; i.e. store what variant is currently dominant: 0 or 1
  let temp hatch-new ; create a new turtle, do the rewiring. Returns the turtle's who number for use in the next few lines

  if is-turtle? turtle temp ;CHECKING THIS TURTLE WASNT KILLED OFF IN THE REWIRING!!!
  [
    ask turtle temp
    [
      interact temp TRUE  ;this is the new turtle choosing a variant based on its neighbours.
      innovate ;this is the new turtle potentially randomly picking a color. Depends on the innovation parameter.
    ]
  ]

  if ( categorical-speakers = FALSE )
  [
    ask turtles
      [
        interact who FALSE ; i.e. let all turtles update variants based on their neighbours.
        innovate ; i.e. potentially just randomly change, with probability governed by the innovation parameter slider
      ]
    ]

  ask turtles [ update-color ]

  ask turtles
  [
    set degree count link-neighbors ; useful for various things including reporters, and the rewiring algorithm.
 ; set label degree
  ]

  repeat 30 [ layout-spring turtles links 0.2 15 1 ] ;this slows things down a lot

  ; calculate which variant is dominant

  if ( count ( turtles with [ variant = 0 ] ) / count turtles ) >= 1 - delta  [ set dominant 0 ]  ; then 0 is dominant
  if ( count ( turtles with [ variant = 1 ] ) / count turtles ) >= 1 - delta  [ set dominant 1 ]

  if dominant != previous-dominance [ set shift shift + 1] ; increment shift variable, if we have had a shift
  tick



end



to-report hatch-new

  let temp -1

  create-turtles 1
  [
    set node-id who
    set temp who
    setxy random-xcor random-ycor

   set degree count link-neighbors
 ;  set label degree
    set label-color blue
   ; set label who
  ]

  rewire temp ; this is Kahunen's rewiring algorithm, making the new guy connect preferentially to those nodes that are higher degree. Depends on k and preferentiality


  ask turtles [ update-color ]

  ask one-of turtles [ die ] ; according to Kauhanen's algorithm, this actually comes before newly hatching a turtle, but for some reason this decreases the population over time.

  report temp

end

to rewire [ is-new-number ] ; if it's a new turtle, this will be a who number. Otherwise pass -1 to the function.

  let ktemp 0

  let probability preferentiality-sigma
  foreach sort-on [degree] turtles ; for the top turtle in the queue
  [
    the-turtle -> ask the-turtle [
     if who !=  is-new-number ;;otherwise the baby turtle will try to link to itself

          [
            let temprandom random-float 1
            if (temprandom <= probability and ktemp < k) ; if k has not yet been reached
            [
             ; show temprandom
              create-link-with turtle is-new-number ; with probability sigma, the top turtle should link to the new turtle
              set ktemp ktemp + 1
             ]
              set probability (1 - preferentiality-sigma) ; then with probability 1-sigma
              if (random-float 1 <= probability  and ktemp < k) ; if k has not yet been reached
              [
               ask one-of other turtles
               [
                 if who != is-new-number [ create-link-with turtle is-new-number ] ; don't link to itself
               ]
                set ktemp ktemp + 1
              ] ; grab other random turtle and link it

          ] ; end if node-id loop.
    ] ; end ask the turtle loop
    set probability preferentiality-sigma ; reset prob to sigma
  ]

end

to innovate  ; this is the random innovation based on the innovation parameter.
  if random-float 1 <= innovation
  [
    set variant one-of [ 0 1 ]
    update-color
  ]
end




to interact [ turtle-number bool-new ] ;; this now can be used for any turtle (new is a boolean to say whether it's the new turtle that just hatched or not)

  ask turtle turtle-number [

  let zeroneighbours 0
  let oneneighbours 0

  let newrandom random-float 1
    if  ( count link-neighbors != 0 )
    [
      set zeroneighbours ( count link-neighbors with [variant = 0] / count link-neighbors )
      set oneneighbours ( count link-neighbors with [variant = 1] / count link-neighbors )
    ]

    ifelse bool-new = TRUE
    [
      ifelse newrandom <= zeroneighbours [ set variant 0 ]
      [set variant 1 ]
    ]

    [
      if random-float 1 < interaction-effects ; the higher the interaction effects slider is, the higher the chance that any individual turtle will acquire a new variant, and the one they acquire is most likely to be the one most widely spoken by his/her neighbours.
      [
        ifelse newrandom <= zeroneighbours [ set variant 0 ]
        [set variant 1 ]
      ]
    ]


    ;if random-float 1 <= innovation [ set variant one-of [ 0 1 ]  ]

  ]

end





;;; BEGINNING OF THE SPEECH INTERACTION PROCEDURES

;to interact ;;
  ;; choose random partner from linked nodes to interact with.
 ; let partner one-of link-neighbors;;
  ;let result 5
 ; if partner != nobody
  ;[

  ;ask partner [
  ;  if variant = 0 [ ask myself [set variant 0]] ; this has no randomness - you will switch to partner's variant
  ;  if variant = 1 [ ask myself [set variant 1] ]
  ;  ] ;; now the "ask" block is closed

 ; ];; now the if block is closed

;end


;; END OF THE SPEECH INTERACTION PROCEDURES
@#$#@#$#@
GRAPHICS-WINDOW
419
10
847
439
-1
-1
12.0
1
26
1
1
1
0
0
0
1
-17
17
-17
17
1
1
1
ticks
30.0

BUTTON
220
22
286
55
set up
setup
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
304
23
367
56
go
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

BUTTON
220
67
409
100
(re)distribute variants
ask turtles [set variant one-of [0 1]\nif variant = 0 [set color black ]\nif variant = 1 [set color white ] ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
858
12
1233
166
Variants
time
totals
0.0
10.0
0.0
50.0
true
true
"set-plot-background-color gray" ""
PENS
"variant-0" 1.0 0 -16777216 true "" "plot count turtles with [ variant = 0]"
"variant-1" 1.0 0 -1 true "" "plot count turtles with [ variant = 1 ]"

SLIDER
13
68
213
101
preferentiality-sigma
preferentiality-sigma
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
12
23
184
56
innovation
innovation
0
0.1
0.1
0.001
1
NIL
HORIZONTAL

INPUTBOX
860
361
1021
421
number-of-wires
50.0
1
0
Number

SWITCH
861
462
1019
495
random-wiring
random-wiring
0
1
-1000

INPUTBOX
14
138
175
198
number-of-black-nodes
50.0
1
0
Number

INPUTBOX
16
210
175
270
number-of-white-nodes
0.0
1
0
Number

SWITCH
860
425
1022
458
random-nodes
random-nodes
0
1
-1000

SWITCH
1038
462
1247
495
categorical-speakers
categorical-speakers
0
1
-1000

SLIDER
1038
384
1223
417
interaction-effects
interaction-effects
0
1
0.7
0.1
1
NIL
HORIZONTAL

SLIDER
15
283
246
316
k-connections-if-random
k-connections-if-random
1
number-of-black-nodes + number-of-white-nodes - 1
20.0
1
1
NIL
HORIZONTAL

BUTTON
1038
341
1165
374
read from file
import-network
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
1038
423
1309
456
k-connections-if-read-from-file
k-connections-if-read-from-file
1
k
7.0
1
1
NIL
HORIZONTAL

PLOT
858
172
1058
322
Degree distribution
degree
number of nodes
0.0
20.0
0.0
40.0
true
false
"set-plot-y-range 0 count turtles\nset-plot-x-range 0 k-connections-if-random + 1\nset-histogram-num-bars 20" ""
PENS
"default" 1.0 1 -16777216 true "histogram [degree] of turtles" "histogram [degree] of turtles"

SLIDER
221
126
393
159
delta
delta
0
1
0.3
0.1
1
NIL
HORIZONTAL

MONITOR
1088
173
1235
230
Dominant variant
dominant
0
1
14

MONITOR
1088
237
1145
294
Shifts
shift
0
1
14

@#$#@#$#@
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

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line-half
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
import-network
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="children links from file reproduce yes" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>(count turtles = 1) or ( (ticks / ticks-per-year = 150 ))</exitCondition>
    <metric>mean [lexicon] of turtles</metric>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="peer-networks?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="leaving-rate">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-per-year">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marsters-doesnt-change?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="historically-accurate?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_nodes">
      <value value="&quot;with children&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="childrens-language">
      <value value="&quot;bilingual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduction?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="linksfile">
      <value value="&quot;linkswithchildren.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate">
      <value value="0.3"/>
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
