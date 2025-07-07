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
