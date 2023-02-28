# Megafaunal Hunting Pressure Model - V1.1

## A model of human hunting pressure on a population of male and female animals in a possibly variable and dynamic environment. 

The MHPM divides the prey species into male and female
animals that are modeled independently to allow for sexual dimorphism
and the possibility that hunters will prefer one over the other. Both
foragers and prey animals have some (limited and biased) information
about local conditions that they use to plan their movement and
subsistence decisions. Forager decisions are still based on optimality
logic, but the information in the decision models is more realistic than
in classic numerical OFT modeling. There are feedback loops connecting
the consequences of all these decisions in a linked complex adaptive
social-ecological system that create temporal and spatial dynamics not
typically incorporated into OFT modeling.

### Foraging dynamics

The MHPM divides the prey species into male and female animals that are
modeled independently to allow for sexual dimorphism and the possibility
that hunters will prefer one over the other. In classic OFT, the payoff
(or "profitability"), *Pi* , of a potential prey species *i* is
described as the food energy, *Ei,* gained (e.g., in kcal) per unit
time, *ti*, spent "processing" the prey once encountered (this includes
the time to pursue, process, and eat the animal):

`Pi = Ei / ti`

\(1\)

Alternatively, profitability may be calculated as food energy, *Ei,*
gained minus energy costs expended handling, *hi,* of the prey item so
that the profitability equation takes the form:

`Pi = Ei - hi`

\(2\)

To establish a "Diet Breadth" model, the profitability of all potential
prey species must be known, as well as the average "search cost," *S*,
required to find an individual prey animal of each species. To be
included in the diet, the profitability of prey species *k* must exceed
or equal the potential profitability of all other higher-ranked prey
species (*i* to *j*) when search costs are factored in:

`if: Pk PiPj - Sk, then include animal k in diet`

\(3\)

Thus, if a first-ranked prey animal is encountered it is always pursued,
processed, and eaten. If a lower-ranked prey animal is encountered, it
is only pursued, processed, and eaten if the densities of all
higher-ranked animals are low enough to offset the reduced payoff
offered by the lower-ranked animal. This logic assumes the forager to
know *a priori* the search time for all prey species within the entirety
of the foraging environment, to always estimate these values correctly,
and to never deviate from this decision logic. These issues are often
cited as weaknesses of classical OFT, and the rebuttal is that OFT
models are simply internally consistent baseline hypotheses against
which to evaluate foraging datasets. In the MHPM, we combine OFT with a
CAS perspective to move beyond these debates. Specifically, we leverage
the spatiality and time-transgressive nature of the ABM modeling
formalism to incorporate the effects of error and bias into the OFT
decision logic in a way that may more realistically simulate foraging
decisions, while still allowing for optimality logic to be used as a
baseline.

In our model, the foraging decision logic reflects a two-prey diet
breadth model that also incorporates some assessment of potential future
search costs in addition to prior "sunk" search costs. Forager agents
move and search iteratively in a dynamic landscape populated by a
population of mobile prey animal agents. The only two prey choices in
the model are assumed to be males and females of the same species, which
can be individually parameterized in the model interface with distinct
intrinsic food energy payoff and handling costs. Optionally, an
additional food energy value for calves can be added to that of pregnant
or recently postpartum females still rearing their offspring,
effectively producing a third prey choice:

`Pmale = Emale - hmale`

\(4\)

`Pfemale = Efemale - hfemale`

\(5\)

`Pfemale with calf = Efemale + Ecalf - hfemale`

\(6\)

At the instantiation of any model run, the above payoffs are calculated
from the values set in the model interface, a prey ranking order is
determined, and knowledge of these prey ranks and payoffs is passed to
all forager agents. Forager and prey animals begin to move as time
progresses in a series of discrete time "ticks". A forager agent is
considered to have encountered a potential prey agent in a given tick
when both agents occupy the same or immediately adjacent landscape
cells. At the time of an encounter, the foraging agent conducts a diet
breadth calculation to decide whether to process the encountered prey,
or to continue to search for another prey item.

At each time step, the forager agents "scan" within a pre-set foraging
radius, *r*, to attain the current count of animals, *n*, within the
foraging radius. This is a proxy for the number of prey that are likely
to be nearby, and thus reasonable to consider as plausible alternative
prey choices when a specific prey animal is encountered. With this
information, forager agents then estimate an average search cost, *Sa*,
to keep looking for a nearby first-ranked prey by dividing the area
within the search radius by the number of prey that are within it, and
then multiplying that by the forager movement cost, *m*. In the model,
the foraging radius is delineated as a discrete number of cells, *A*,
that fall completely within a linear radius of *r* around (and
including) the central cell occupied by the forager so that the scanning
formula takes the form:

`Sa = ( A / n ) m`

\(7\)

Where:

``A ⪅ πr2`

\(8\)

The estimated average pay-off, *Pa*, of the animals (*i* to *j*) within
the foraging radius is then calculated as:

`Pa = PiPj /A`

\(9\)

If the payoff of an encountered animal, *Pk*, is higher than the
estimated return of searching for, encountering, and then processing one
of the first ranked prey animals within the search radius, then the
currently encountered lower-ranked animal is processed and eaten:

`if: Pk ≥ Pa - Sa, then consume animal k`

\(10\)

At each time step, the current energy states of the foragers,
*Ecurrent*, are updated as a function of their previous energy state,
*Eprevious*, the forager movement costs, *mforager*, and any new
foraging payoffs, *P*:

`Ecurrent = Eprevious - mforager + P`

\(11\)

Foragers are considered to be experiencing extreme food stress if their
current energy state, *Ecurrent*, is less than the estimated average
search costs, *Sa*. When in extreme food stress, foragers will process
and eat any prey animal they encounter. This accounts for "sunk" search
costs and non-optimal foraging decisions when appropriate:

`if: Ecurrent \< Sa, then consume any encountered animal`

\(12\)

Finally, foragers can optionally be considered to have the ability to
store surplus food. If this option is enabled, then any energy value
gained from the processing of an encountered animal that is in excess of
the maximum consumption capacity (i.e., in excess of 100 percent of
forager energy) can still be consumed in the subsequent time steps.
Foragers will consume this excess at the same rate as the movement cost
per tick, but they will not move or attempt to forage until this excess
is fully consumed.

### Demographic dynamics


Because the main purpose of the MHPM is to understand extinction
dynamics, it includes a detailed prey animal demographic component. When
a male and female prey agent occupy the same or adjacent landscape
cells, they can mate and produce offspring. The probability of a
successful mating is linked to the energy status of the female animal,
where the chance of producing an offspring decreases linearly from 100%
at a full energy state to 0% at a zero energy state. Further, only
females that have not recently calved are able to reproduce. This is
controlled by a birth spacing interval variable, *Tbirth spacing*, that
is set in the user interface. When a female reproduces, a counter, *Tr*,
is set to zero and increases with each successive time tick. If *Tr* is
less than or equal to *Tbirth spacing *then the female is considered to
be pregnant, and eventually post-partum, with a calf:

`if: Tr ≤ Tbirth spacing, then female is with calf`

\(13\)

Once*Tr* is greater than *Tbirth spacing*, the calf is considered to be
full grown and will be weaned and live separately from its mother. 

`if: Tr \> Tbirth spacing, then calf is weaned`

\(14\)

Within the model, weaning spawns a new prey agent in the same landscape
cell as the mother. The sex of the new prey agent is randomly determined
with a 50% probability to be male or female, and it will be instantiated
with the full adult food energy value and handling costs of the
determined sex.

Births are balanced by a variety of causes of death. Any form of death
for a postpartum female within the birth spacing window also includes
the death of the calf. Firstly, any prey animals that are harvested by a
forager in a time step are considered "killed" and are removed from the
simulation environment. Prey animals may also die from a variety of
"natural" causes such as starvation, old age, disease, or non-human
predation. They are instantiated with initial energy states, *E0*, a
typical age of senescence, *Tsenescence*, a maximum possible lifespan,
*Tmax*, and must graze grass to survive. Each movement step (see main
text, Section 4.2.3) reduces an animal's energy state by the animal
movement cost, *manimal*, and each patch of grass encountered is grazed
to replenish an animal's energy by the energy gain value, *Egraze*.

`Ecurrent = Eprevious - manimal + Egraze`

\(15\)

If there is no grass on the current patch, then the energy state of the
animal is determined as:

`Ecurrent = Eprevious - manimal`

\(16\)

If an animal's energy state drops to 0 it will die:

`if: Ecurrent ≤ 0, then animal dies`

\(17\)

In every time step, there is a random chance of death among the
population of animals with energy below a starvation threshold,
*Estarve*. The chance of death is controlled by an internal mortality
variable, *pdeath*:

`for nanimals where: Ecurrent \< Estarve, a random selection of nanimals
\* *pdeath* die`

\(18\)

Likewise, if an animal reaches maximum lifespan, *Tmax*, they will die:

`if: Tcurrent ≥ Tmax, then animal dies`

\(19\)

But, as animals surpass the age of senescence, there is an increasing
probability of death from old age within that population of senescent
animals, again controlled by the internal rate of mortality, *pinternal
death*:

`for nanimals where: Tcurrent ≥ Tsenescence, and: Tcurrent \< Tmax, a
random selection of nanimals \* pinternal death die`

\(20\)

There is also a stochastic external mortality probability, *pexternal
death*, that can be adjusted to simulate a percentage of animals that
die from disease, accidents, or non-human predation at each time-step:

`for nanimals, a random selection of nanimals \* pexternal death die`

\(21\)

In each time step, animal ages are first increased by one. They then
move to a new patch, and movement costs are deducted. They then graze
grass if possible, and any energy gains are added. Then, deaths are
assessed in the order of 1) human predation, 2) starvation risk, 3) old
age risk, and finally, 4) external mortality risk. Next, mating occurs
if conditions are correct. Finally, any female animals at the end of
their birth spacing interval will wean their calves, which are spawned
as new prey animal agents. Thus, at the end of each time step, the total
new size of the population of prey animals is set for the next time
step, and each animal has a newly updated set of energy and lifespan
attributes.

Forager demography in the model is much simpler than animal demography:
foragers may be either "immortal" or allowed to die if their energy
state reaches zero:

`if: Ecurrent ≤ 0, then forager dies`

\(22\)

This simplicity is purposeful, as it allows controlled experimentation
about the effect of human foraging pressure on prey population dynamics.
If foragers are made "immortal," then hunting pressure is constant
across time and the direct impact of human predation on extinction
processes is easier to understand. If foragers are allowed to die of
starvation, then hunting pressure may equilibrate with prey demographic
processes over time, and more nuanced (but more difficult to follow)
patterns in predator-prey dynamics may unveil.

### Movement dynamics


We incorporate realistic movement algorithms for forager and animal
agents. Forager agents are programmed to move with some foraging
information feedback as local conditions change. At each time step,
forager agents will turn to face the closest highest-ranked prey animal
within their foraging radius, and then will advance one cell in that
direction. If there are no nearby animals, then the forager proceeds in
a true "random-walk" fashion by choosing a random heading and advancing
to the nearest cell in that direction. For each movement, a
predetermined movement cost is incurred.

Animal agents are programmed to instinctively move as a herd with some
feedback about local grazing conditions. At each time step, animals will
first attempt to face the nearest patch of grass within a 3-cell radius
and advance one cell in that direction. If there is no grass in this
radius, they will instead align their heading towards the average
heading of animals that are within a 5-cell radius and advance one cell
in that direction. If there are also no nearby animals, then the animal
will proceed in a true "random-walk" fashion by advancing one cell in a
randomly chosen direction. As above, for each movement, a predetermined
movement cost is incurred.

An emergent property of these movement algorithms is that buffalo often
self-organize into herds that will \"migrate\" in waves following the
seasonal regrowth of grass patches (see main text, Section 4.2.4), with
hunters following along, often in "bands" of multiple foragers, behind
them.

### Environmental dynamics


Finally, the model incorporates several environmental dynamics
components that can be switched on or off in any given experiment. These
are controlled by a set of variables related to the spatial and temporal
patterning of grass and grass regrowth. The basic spatial patterning of
grass in the environment is determined by the grass proportion,
*pgrass*, where the total number of grassed cells is determined by a
random selection of ngrass cells from the total number of landscape
cells, *ntotal*:

`ngrass = pgrass \* ntotal`

\(23\)

If grass regrowth is turned off, then the spatial patterning of grass
never changes throughout a simulation run, and grass will always be
available to be grazed in a grassed patch. Turning on grass regrowth
enables initially grass-covered patches to become depleted when grazed
by prey animals. These patches will remain depleted of grass for a
user-determined number of time-steps, *Tgrass regrowth*, before the
grass is replenished. In this situation, the current number of grassed
patches, *ngrass current*, is determined by the following equation:

`ngrass current = ngrass - ngrazed + nregrown`

\(24\)

Where:

`nregrown = ngrazed in time step {Tcurrent - Tgrass regrowth}`

\(25\)

If regrowth is turned on, a "keep-initial" option can also be turned on,
which limits grass regrowth only to areas that were initially vegetated
when the model was initialized. If this is turned off, but regrowth is
on, then grass can regrow anywhere.

Finally, an optional seasonality slider can enable seasonal cycling in
the growth of grass. The seasonality proportion *Ps* interacts with a
year-length *Tyear* temporal variable to set up a growing season of
Tgrowing ticks and dry season of Tdry ticks:

`Tgrowing = Ps \* Tyear`

\(26\)

`Tdry = Tyear - Tgrowing`

\(27\)

Note that values of *Ps* less than 0.5 indicate shorter growing seasons,
values of *Ps* larger than 0.5 indicate longer growing seasons, and *Ps*
= 1 indicates no seasonality. These seasons operate within a yearly
cycle of Tyear ticks and overlay grazing regrowth such that grass grazed
in the growing season will regrow within that season according the the
regrowth time, *Tgrass regrowth*:

`if Tcurrent mod Tyear =\< Tgrowing, nregrown = ngrazed in time step
{Tcurrent - Tgrass regrowth}`

However, grass that is grazed in the dry season will not regrow again
until the start of the next growing season:

`if Tcurrent mod Tyear \> Tgrowing, then nregrown = ngrazed in time steps
{Tyear - Tdry}`

\(26\)

Thus, at the one extreme, the environmental components of the model can
be set as completely static with continual grass coverage on every patch
without the effect of grazing, or at the other, very patchy grass that
is grazed and then regrows continually or seasonally.

### Temporal and Spatial Scale

The spatial and temporal scale of the MHPM needs to be set at the start
of any modeling experiment. These are determined by setting the values
of a core set of temporal and spatial variables. Time steps in the
NetLogo interface are called "ticks." The main temporal variable is the
number of ticks per year, *Tyear* , which determines the temporal
granularity of the model run. Other temporal variables are set either as
proportions of this value or must manually be set in relation to this
value. For example, the seasonality proportion variable automatically
sets the length in number of ticks of the growing season (and, hence,
also the dry season) within a year, but the grazing regrowth timer
specifically sets the number of ticks required for a previously grazed
patch to regrow during the season of grass growth. Other manual temporal
variables are the age of senescence and maximum lifespan of animals,
which are each set as numbers of ticks.

The size of the model world is set by determining the number of
landscape cells ("patches" in NetLogo) on each axis of the world. The
absolute size of a patch in relation to real world distance measures are
determined as a function of the number of ticks per year and a ratio of
typical distances covered by the modeled prey animals per unit time.
Thus, the total number of landscape patches should be great enough to
encompass a realistic region of interest that is large enough to allow
interesting movement dynamics, but not so large that it unnecessarily
increases the computational load required to run the model.

## License

This software is made available under the GNU GPL v3 license. Please cite the authors if you use this model or reuse the code.
