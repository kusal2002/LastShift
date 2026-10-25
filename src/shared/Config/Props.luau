--!strict
-- Which imported model dresses each spawned gameplay object. Paths are "Kit/Name" inside
-- ServerStorage.Props (synced by Rojo from assets/props/<Kit>/<Name>.rbxm).
-- If a model hasn't been imported yet, the object keeps its placeholder shape, so the game
-- works at every stage of the art upgrade.
--
-- Pivot rule for these models: set the Model's pivot at its visual centre (Studio: Pivot >
-- Reset, or Edit Pivot). PropService places that pivot exactly where the placeholder sits.
return table.freeze({
	Fuse = "Mission/Fuse",
	NoiseMaker = "Mission/NoiseMaker",
	Evidence = table.freeze({
		Recording = "Mission/CassetteTape",
		Document = "Mission/Folder",
		Reading = "Mission/Printout",
		Visual = "Mission/Photograph",
	}),
})
