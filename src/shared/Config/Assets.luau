--!strict
-- The only place external asset IDs may live. Empty on purpose: no verified assets
-- have been chosen yet, and gameplay code must work when an entry is missing.
return table.freeze({
	Sounds = table.freeze({} :: { [string]: string }),
	Images = table.freeze({} :: { [string]: string }),
})
