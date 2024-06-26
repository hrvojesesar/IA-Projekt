breed [serviseri serviser]
breed [klijenti klijent]

serviseri-own [
 id
 vrste-bicikla
 status
 vrijemePopravka
 privremeni ; Da li je serviser aktivan tijekom cijelog dana ili je privremeni
]

klijenti-own [
  id
  tipBicikla
  vrijemeDolaska
  vrijemeCekanja
  target-x
  target-y
  target-serviser
  exit
  naPopravku
  popravljeno
  vrijemePopravka
  ideKaIzlazu
]

globals [
 cijenaRadaPoSatu
 naplataUsluge
 ukupnaZarada
 ukupnaCijenaRada
 klijentiKojiPredugoCekaju
 uspjesnePopravke
 neuspjesnePopravke
 uspjesnost
 trenutniSat
 radnoVrijemeKraj
 klijentiUTrenutnomSatu
 rasporedDolaskaKlijenata
 ulaz-patch
 izlaz-patch
 serviseriPostavljeni
 pozicijeServisera
 signal-create-serviser
 novi-serviser-tip
 ukupnoKlijenata
 preostalo-vrijeme
 profit
]

to setup
  clear-all
  setup-varijable
  setup-ulaz
  setup-izlaz
  reset-ticks
  postavi-raspored-dolaska-klijenata
  set serviseriPostavljeni false
  set pozicijeServisera [[-20 -15] [0 0] [-20 15] [-20 0] [20 15] [0 15] [20 -15] [20 0] [0 -15]]
  set signal-create-serviser false
  set novi-serviser-tip ""
  set profit 0

  show (word "Trenutni sat: " trenutniSat "h")
end

to go
  if ticks = radnoVrijemeKraj [
    ; Ažuriraj ukupnu cijenu rada za stalne servisere za zadnji sat
    ask serviseri with [privremeni = false] [
      set ukupnaCijenaRada ukupnaCijenaRada + cijenaRadaPoSatu
    ]
    show (word "Došao je kraj radnog vremena!")
    kraj-radnog-dana
    stop
  ]

  if not serviseriPostavljeni [
    setup-serviseri
    set serviseriPostavljeni true
  ]

  set preostalo-vrijeme radnoVrijemeKraj - ticks

  if ticks mod 60 = 0 and ticks > 0 [
    set trenutniSat trenutniSat + 1
    postavi-raspored-dolaska-klijenata
    show (word "Trenutni sat: " trenutniSat "h")

    ; ažuriraj ukupnu cijenu rada za stalne servisere
    ask serviseri with [privremeni = false] [
      set ukupnaCijenaRada ukupnaCijenaRada + cijenaRadaPoSatu
    ]
  ]

  if member? (ticks mod 60) rasporedDolaskaKlijenata [
    create-novi-klijenti
    set klijentiUTrenutnomSatu klijentiUTrenutnomSatu + 1
    show (word "Broj klijenata u trenutnom satu: " klijentiUTrenutnomSatu)
  ]

  ; Provjera da li novi serviser treba biti aktiviran
  if signal-create-serviser [
    create-new-serviser-for-klijent novi-serviser-tip
    set signal-create-serviser false
    set novi-serviser-tip ""
    povecaj-broj-aktivnih-servisera
  ]

  ask klijenti [
    klijent-logika
  ]

  tick
end

to-report pronadji-najblizeg-slobodnog-servisera [trenutni-klijent]
  let najblizi-serviser nobody
  let minimalna-udaljenost max-pxcor * max-pycor
  let ulaz-x [pxcor] of ulaz-patch
  let ulaz-y [pycor] of ulaz-patch

  ask serviseri [
    if status = "slobodan" and member? [tipBicikla] of trenutni-klijent vrste-bicikla [
      let serviser-x [pxcor] of self
      let serviser-y [pycor] of self
      if serviser-x > ulaz-x [ ; Serviser mora biti desno od ulaza
        let delta-x (serviser-x - ulaz-x)
        let delta-y (serviser-y - ulaz-y)
        let udaljenost sqrt (delta-x * delta-x + delta-y * delta-y)
        if udaljenost < minimalna-udaljenost [
          set minimalna-udaljenost udaljenost
          set najblizi-serviser self
        ]
      ]
    ]
  ]

  if najblizi-serviser != nobody [
    ask najblizi-serviser [
      set status "zauzet"
    ]
  ]

  report najblizi-serviser
end

to klijent-logika
  ; Ako klijent nije na popravku i popravka nije završena
  if naPopravku = false and popravljeno = false and ideKaIzlazu = false [
    ; Pronađi najbližeg slobodnog servisera koji može popraviti klijentov tip bicikla
    if target-serviser = nobody [
      set target-serviser pronadji-najblizeg-slobodnog-servisera self
    ]

    ifelse target-serviser != nobody [
      set target-x [pxcor] of target-serviser
      set target-y [pycor] of target-serviser

      face target-serviser
      wait 1
      move-to target-serviser

      ; Pomjeranje prema serviseru
      if distance target-serviser < 1 [
        set naPopravku true
        ask target-serviser [
          set status "zauzet"
        ]
        set vrijemePopravka random 30 + 1 ; Nasumično vrijeme popravke između 1 i 30 tickova

        show (word "Klijent " who " je stigao kod servisera " [id] of target-serviser " za popravku.")
        show (word "Vrijeme popravka: " vrijemePopravka " minuta!")
      ]
    ] [
      ; Ako nema slobodnih servisera
      show (word "Klijent " who " ne može pronaći slobodnog servisera ili slobodan serviser ne može popraviti njegov tip bicikla i zato ćemo aktivirati novog servisera.")
      set signal-create-serviser true
      set novi-serviser-tip tipBicikla
    ]
  ]

  ; Ako je klijent na popravku
  if naPopravku = true [
    ; Ažuriraj vreme popravke
    set vrijemePopravka vrijemePopravka - 1
    set vrijemeCekanja vrijemeCekanja + 1

    if vrijemeCekanja > 15 or vrijemePopravka > preostalo-vrijeme [
      show (word "Klijent " who " predugo čeka ili nema dovoljno vremena za popravak te umire.")
      set klijentiKojiPredugoCekaju klijentiKojiPredugoCekaju + 1
      set neuspjesnePopravke neuspjesnePopravke + 1
      ask target-serviser [
        set status "slobodan"
        if privremeni = true [
          smanji-broj-aktivnih-servisera
          die
        ]
      ]
      die
    ]

    ; Ako je popravka završena
    if vrijemePopravka <= 0 [
      set naPopravku false
      set popravljeno true
      set ideKaIzlazu true
      ask target-serviser [
        set status "slobodan"
        if privremeni = true [
          show (word "Usli smo u proceduru!")
          smanji-broj-aktivnih-servisera
          die
        ]
      ]
      set target-serviser nobody
      show (word "Klijentu " who " je uspješno završen popravak bicikla.")
      set uspjesnePopravke uspjesnePopravke + 1
      set ukupnaZarada ukupnaZarada + naplataUsluge
    ]
  ]

  ; Ako klijent ide ka izlazu
  if ideKaIzlazu = true [
    face izlaz-patch
    move-to izlaz-patch
    show (word "Klijent " who " je otišao iz servisa.")
    wait 1
    die
  ]
end

to povecaj-broj-aktivnih-servisera
  set broj-servisera broj-servisera + 1
  ; nije potrebno mijenjati slider
end

to smanji-broj-aktivnih-servisera
  set broj-servisera max (list 0 (broj-servisera - 1))
  ; nije potrebno mijenjati slider
end

to create-new-serviser-for-klijent [tipBiciklaa]
  let pozicije-kopija []
  foreach pozicijeServisera [ p ->
    set pozicije-kopija lput p pozicije-kopija
  ]
  let pozicija-item nobody

  while [pozicija-item = nobody and not empty? pozicije-kopija] [
    let p one-of pozicije-kopija
    if not any? serviseri-on patch (item 0 p) (item 1 p) [
      set pozicija-item p
    ]
    set pozicije-kopija remove p pozicije-kopija
  ]

  ifelse pozicija-item != nobody [
    create-serviseri 1 [
      set id who
      set shape "person service"
      set color magenta
      set size 3
      set vrste-bicikla (list tipBiciklaa one-of ["dječji" "brdski" "trkaći"])
      set status "slobodan"
      set vrijemePopravka 0
      set privremeni true ; Mark this serviser as temporary
      setxy (item 0 pozicija-item) (item 1 pozicija-item)

      show (word "Novi privremeni serviser " id " je kreiran i može popraviti vrste bicikala: " vrste-bicikla)
    ]
  ] [
    show (word "Nema dostupnih pozicija za novog servisera.")
  ]
end

to postavi-raspored-dolaska-klijenata
  set klijentiUTrenutnomSatu 0
  set rasporedDolaskaKlijenata []
  let brojKlijenataPoSatu 0
  if trenutniSat >= 8 and trenutniSat < 11 [
    set brojKlijenataPoSatu 6
  ]
  if trenutniSat >= 11 and trenutniSat < 15 [
    set brojKlijenataPoSatu 12
  ]
  if trenutniSat >= 15 and trenutniSat < 18 [
    set brojKlijenataPoSatu 8
  ]
  while [length rasporedDolaskaKlijenata < brojKlijenataPoSatu] [
    let randomTick random 60
    if not member? randomTick rasporedDolaskaKlijenata [
      set rasporedDolaskaKlijenata lput randomTick rasporedDolaskaKlijenata
    ]
  ]
  set rasporedDolaskaKlijenata sort rasporedDolaskaKlijenata
end

to setup-varijable
  set cijenaRadaPoSatu 25
  set naplataUsluge 15
  set ukupnaZarada 0
  set ukupnaCijenaRada 0
  set klijentiKojiPredugoCekaju 0
  set uspjesnePopravke 0
  set neuspjesnePopravke 0
  set uspjesnost 0
  set trenutniSat 8  ;; Početni sat je 8, tako da prva promjena sata bude 9:00
  set radnoVrijemeKraj 600
  set klijentiUTrenutnomSatu 0
  set rasporedDolaskaKlijenata []
  set ukupnoKlijenata 0
  set preostalo-vrijeme 0
end

to setup-ulaz
  ask patch (min-pxcor) 0 [
   set pcolor green
  ]
  set ulaz-patch one-of patches with [pcolor = green]
end

to setup-izlaz
  ask patch 45 0 [
    set pcolor red
  ]
  set izlaz-patch one-of patches with [pcolor = red]
end

to setup-serviseri
  let pozicije [[-20 -15] [0 0] [-20 15] [-20 0] [20 15] [0 15] [20 -15] [20 0] [0 -15]]
  let broj-servisera-value broj-servisera
  create-serviseri broj-servisera-value [
    set id who
    set shape "person service"
    set color red
    set size 3
    ;; Svakom serviseru dodjeljujemo 2 slučajna tipa bicikla koje može popraviti
    set vrste-bicikla n-of 2 ["dječji" "brdski" "trkaći"]
    set status "slobodan"
    set vrijemePopravka 0
    set privremeni false ; Mark this serviser as permanent

    let pozicije-item one-of pozicije
    setxy (first pozicije-item) (last pozicije-item)
    set pozicije remove pozicije-item pozicije

    ;; Show servicer info
    show (word "Serviser " id " može popraviti sljedeće vrste bicikala: " vrste-bicikla)
  ]
end

to create-novi-klijenti
  create-klijenti 1 [
    set shape "bike"
    set color one-of remove black (list red green blue yellow orange cyan magenta white brown sky violet pink)
    setxy [pxcor] of ulaz-patch [pycor] of ulaz-patch
    set tipBicikla one-of ["dječji" "brdski" "trkaći"]
    set vrijemeDolaska ticks
    set vrijemeCekanja 0
    set exit false
    set naPopravku false
    set popravljeno false
    set vrijemePopravka 0
    set target-serviser nobody
    set ideKaIzlazu false
    set ukupnoKlijenata ukupnoKlijenata + 1

    ; Provjera je li dovoljno vremena za popravak
    ifelse preostalo-vrijeme < 15 [
      show (word "Klijent " who " dolazi prekasno za popravak i odmah će biti uklonjen.")
      set klijentiKojiPredugoCekaju klijentiKojiPredugoCekaju + 1
      set neuspjesnePopravke neuspjesnePopravke + 1
      die
    ] [
      show (word "Klijent " who " dolazi u servis sa svojim biciklom tipa: " tipBicikla)
    ]
  ]
end

to kraj-radnog-dana
  set profit ukupnaZarada - ukupnaCijenaRada
  set uspjesnost ukupnaZarada / ukupnaCijenaRada
  set uspjesnost uspjesnost * 100

  spremiUExcel
end

to spremiUExcel
  let zaokruzenaUspjesnost precision uspjesnost 3
  let file-path (word user-directory "rezultati.csv")
  file-open file-path
  file-print (word "Ukupna dnevna zarada (zbroj naplata usluga): " ukupnaZarada)
  file-print (word "Ukupni dnevni troskovi: " ukupnaCijenaRada)
  file-print (word "Ukupni profit: " profit)
  file-print (word "Uspjesnost: " zaokruzenaUspjesnost "%")
  file-print (word "Broj uspjesnih popravaka: " uspjesnePopravke)
  file-print (word "Broj neuspjesnih popravaka: " neuspjesnePopravke)
  file-print (word "Broj klijenata koji su predugo cekali: " klijentiKojiPredugoCekaju)
  file-print (word "\n")
  file-print (word "\n")
  file-close
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
1401
552
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-45
45
-20
20
0
0
1
ticks
30.0

BUTTON
110
36
173
69
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
17
87
80
120
go
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

BUTTON
20
37
83
70
setup
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

SLIDER
20
136
192
169
broj-servisera
broj-servisera
0
9
9.0
1
1
NIL
HORIZONTAL

MONITOR
25
181
168
226
Ukupna dnevna zarada
ukupnaZarada
17
1
11

MONITOR
13
239
180
284
Ukupna dnevna cijena rada
ukupnaCijenaRada
17
1
11

MONITOR
15
297
178
342
Klijenti koji predugo čekaju
klijentiKojiPredugoCekaju
17
1
11

MONITOR
23
350
144
395
Uspješne popravke
uspjesnePopravke
17
1
11

MONITOR
15
406
150
451
Neuspješne popravke
neuspjesnePopravke
17
1
11

MONITOR
22
466
154
511
Ukupan broj klijenata
ukupnoKlijenata
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
false
1
Line -7500403 false 163 183 228 184
Circle -7500403 false false 213 184 22
Circle -7500403 false false 156 187 16
Circle -16777216 false false 28 148 95
Circle -16777216 false false 24 144 102
Circle -16777216 false false 174 144 102
Circle -16777216 false false 177 148 95
Polygon -2674135 true true 75 195 90 90 98 92 97 107 192 122 207 83 215 85 202 123 211 133 225 195 165 195 164 188 214 188 202 133 94 116 82 195
Polygon -2674135 true true 208 83 164 193 171 196 217 85
Polygon -2674135 true true 165 188 91 120 90 131 164 196
Line -7500403 false 159 173 170 219
Line -7500403 false 155 172 166 172
Line -7500403 false 166 219 177 219
Polygon -16777216 true false 187 92 198 92 208 97 217 100 231 93 231 84 216 82 201 83 184 85
Polygon -7500403 true true 71 86 98 93 101 85 74 81
Rectangle -16777216 true false 75 75 75 90
Polygon -16777216 true false 70 87 70 72 78 71 78 89
Circle -7500403 false false 153 184 22
Line -7500403 false 159 206 228 205

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

person service
false
0
Polygon -7500403 true true 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -1 true false 120 90 105 90 60 195 90 210 120 150 120 195 180 195 180 150 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Polygon -1 true false 123 90 149 141 177 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -2674135 true false 180 90 195 90 183 160 180 195 150 195 150 135 180 90
Polygon -2674135 true false 120 90 105 90 114 161 120 195 150 195 150 135 120 90
Polygon -2674135 true false 155 91 128 77 128 101
Rectangle -16777216 true false 118 129 141 140
Polygon -2674135 true false 145 91 172 77 172 101

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
