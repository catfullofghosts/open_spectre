!!! REMEMBER IF SOMETHIGN DOESNT WORK CHECK THE REST AND H/Vsync are correct poliarity!!!!


NEXT build check:
done - check oscilator wavweforms working now with derivation added (do sim first) -- fixed
- check osc speed slow on vertical sync, is it fast enough now (changed from 23-17 clock counter per toggle)-- highest speed not fastenough, slowest speed way too slow for verical

issue - check edge thickness comes from the correct diretion -- direction of width fixed but now some lines missing vericly?!
- check overlay debug and sprite debug (full signal debug using 'dont touch') -- overlay fixed ems tester.py makes a grid across the whole screen
done----- - check slow counters still work after mid frame gating
- 1bit CA full debug, working, check the new expanded rules to see if that helps make ti more interesting
- check resolution change
done------ check if alpha blending still has the hard right edge ---fixed


to do before next build:
- look for 1bit ca issue -- added debug put reset to 0
- add dont touch to overlay signals added debug
- fix edge direction -- fixed edges, were backwards-- working but falling and rising are revered in the matrix? were they always like that
- try to fix osc derivation issue -- out assign was only in th sinwave part of the case statement
- check if alpha blending still has the hard right edge



2/7/2026:

spriutes look like they are working but overlay isnt for some reason
frame buffer addr seems to jump and is not smooth
add full mark debug, if syncs are backwards then why do sprites work (sort of)?




check oscilators sync select what should those be connected to? - they look fine but the gui has an extra value it that doesnt do anything
does osc sinwave look right compare to actual video
when sync is 2 = vertical sync highest freek isnt high enough
also when vert sync sinwave looks blocky- the sin res is too low, should i use sinwave from BGI synth?
osc alph (and maybe all alpha) results in a hard line on the left edge before the alpha takes effect

other waveforms not working now that derivation has been introduced

edge detector width regs dont work on edge detect 1 and 2 only 3 and 4, also sometime a signal gets stuck going through the edge detector?? and we see the full signal not just the edge
* are there really 4 edges out? why == first 2 are thin secodn 2 are thick (now has regs driving thickenss)

!!! EDGE THICKNESS STARTS FROM THE WRONG EDGE!!! and gets thicker towards the rising edge!!!

video effects and frame stats are broken

debug 1bit CA cant see anything!!! you need to feed it with invert 1, maybe it should be fed by count 9 at satartup by SW, CA inut is actualy XY invert 9 for some reason?!
also CA is stuck after the first signal goes to it it gets stuck and rule changes dotn work



dsm to analoge matrix doent work <- check in next build> -- was in reset !! works now but filter is too strong! -- works now, maybe filter is still too smooth but fix later when looking at actual unit responce

delay works -- is it masked by vertical or horizontal interupt?

-- any shape stuff that has been deiscivered by debug ,- should be fixed now -- it is

working, registers only write %2 but it works in x and y directions-- add control for the counter pix clock devider, so the lines can get more and less chunky --- it creates an odd 3 line smearing, shuld reset oh hs!! <- check next build >

-- add blanking values to blanking video out

-- debug why counters dont seem to run when i change resolution


-- te4st luma key!! -- need to re activate

DONE ---check app changes to slider order work as well as number box to set value


----------------
check new build:

counters only seem to work at lowest res? are they not reset on a format change or clock loss?


note: 27/11/25:
oscilaors are fixed, no discontinuity now,
sqr osc are now symetricxal 

-- vertical sync needs to change the osc range to be much smaller, freq of 01 only just fits on the screen

yeah, but matrix in 50 = 0x32 or 63 = 0x3f dont seem to pull up the outputs oddly, why

- removing that extra clock delay from feedback seems to have messed up feedback now it is not there

to do: 
-add alpha back for osc 1 (done)

- adjust osc 2 freq it isnt very (done)
interesting, should be an non even devision of the main osc -- is + 36 a good value?
also add un sync for osc derivation

osc freq steps are too big!!! - (done) - scaled to 13 bits

-put clock delay for feed back back in and see if that has brough back the feedback (done)

- noise freq needs to be faster (done)
at the low end and slower at the high end - made 13 bits, this wont speed up the fastest speed sadly




-- the video in range, look staggered when you change the values, like i need to scale up all the values? 

-- need to use a dac style look up for the 3 sets of coulurs to get a full range (done add to repo)

--set video in blanking to apropriate value


note: 1/12/25:

check feedback (looks good)

check osc smoothness when changing freq
check osc works for both horz and vert
 - verticly there are only 4 lines , need to work that out
 - unsynced the slowest is still too fast, need a way of deviding by like 8 or something to ge fades that go over multiuple frames


check noise freq range
- at its min freq is still too fast, much need a switch like for oscilators

check fake dacs make colours look ok!!! i like them



note 2/12/15:

-- check feedback when extra ff is removed, should be afeedback path of 1 clock now (NO IT IS BAD!! needs the FF)

-- check if the vertical osc bars are 4x faster now? (yes! needs to be faster still! try + 8)

-- check if osc speed bit slows the freq by a lot check with free running
(yes but make way slower again!!!! when bit is set)

-- check if noise speed selct slows down the noise enouggh
it slows it down a lot, but it needs to be maybe 8 x slower -- good enough for now


-- check the shapegen- do debug

next build check after 2/12/25

--check osc vertical goes fast and slow enough, still needs to be 2x faster!!!!!

-- free running WORKING!!!

-- reg 78 has color encoder bypass bit (bit 1) to turn on/off colour encoding -- test (works)


NEXT TO DO
-- any shape stuff that has been deiscivered by debug

-- add control for the counter pix clock devider, so the lines can get more and less chunky --- it creates an odd 3 line smearing, shuld reset oh hs!!

-- add blanking values to blanking video out

-- debug why counters dont seem to run when i change resolution

-- chenging the pixel devision creats vertical offsets

-- te4st luma key!!


edge detectors need to be reset or something, when you first route them they show the full input signal then when you route them again you see the edge