# Project: Godot + VEsNA light instantiation of the game "Supremacy 1914"

## General description

Do not leave some code for implementation, write a complete code and implement every aspect of it. In case you need to generate some extra code to make it work, do it.

This project represents a reconstruction of the game Supremacy 1914 in godot in @./godot, the logic used with the AI to play the game is made with VEsNA light in @./mind using Agent Speak Language

Every player is a nation who has provinces which produce resources and troops and some of the provinces has double production of resources, while some of them are capitals of the nation.
At this moment a nation can decide to declare war and move armies to attack or defend the provinces

**Keep in mind that the godot part must include the structural features while the mind part must get this feature to implement a reasoning on that, in fact the mind have to simulate the human behaviour so every piece of information about the game itself must be in godot, every piece of information about the reasoning and behaviour of a player must be in mind. If the mind need a game information godot must sends that information to the mind**
