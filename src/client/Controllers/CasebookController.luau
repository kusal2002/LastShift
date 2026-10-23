--!strict
-- The permanent casebook: evidence you have escaped with, grouped by the anomaly it points to,
-- plus how often you've met and identified each anomaly. Helps players learn patterns across runs.
local Client = script.Parent.Parent
local ProfileState = require(Client.ProfileState)
local Theme = require(Client.UI.Theme)
local Overlay = require(Client.UI.Overlay)

local CasebookController = {}

local overlay: Overlay.Overlay? = nil

local function render()
	local current = overlay
	local view = ProfileState.get()
	if current == nil then
		return
	end
	current.clear()
	if view == nil then
		current.title.Text = "CASEBOOK"
		Theme.label(current.body, "Loading your casebook...", 15, Theme.Colors.Muted)
		return
	end
	current.title.Text = `CASEBOOK  {#view.Casebook}/{view.EvidenceTotal}`

	Theme.label(current.body, "ANOMALIES", 15, Theme.Colors.Amber, true)
	for _, record in view.Anomalies do
		local text = if record.Encounters == 0
			then `{record.DisplayName}: not yet encountered`
			else `{record.DisplayName}: met {record.Encounters}x, identified {record.Identified}x`
		Theme.label(
			current.body,
			text,
			14,
			if record.Encounters > 0 then Theme.Colors.Text else Theme.Colors.Muted
		)
	end

	Theme.label(current.body, "EVIDENCE", 15, Theme.Colors.Amber, true)
	if #view.Casebook == 0 then
		Theme.label(
			current.body,
			"No entries yet. Escape with evidence to add it to your casebook.",
			14,
			Theme.Colors.Muted
		)
	end
	for _, record in view.Anomalies do
		local entries = {}
		for _, entry in view.Casebook do
			if entry.AnomalyName == record.DisplayName then
				table.insert(entries, entry)
			end
		end
		if #entries > 0 then
			Theme.label(current.body, `Linked to {record.DisplayName}`, 14, Theme.Colors.Green, true)
			for _, entry in entries do
				Theme.label(
					current.body,
					`{entry.DisplayName}  [{entry.Category}]`,
					14,
					Theme.Colors.Text,
					true
				)
				Theme.label(current.body, entry.Description, 13, Theme.Colors.Muted)
			end
		end
	end
	local missing = view.EvidenceTotal - #view.Casebook
	if missing > 0 and #view.Casebook > 0 then
		Theme.label(current.body, `{missing} entries still undiscovered.`, 13, Theme.Colors.Muted)
	end
end

function CasebookController.start()
	overlay = Overlay.new("Casebook", 14, Vector2.new(520, 620))
	ProfileState.changed:Connect(render)
	render()
end

function CasebookController.toggle()
	local current = overlay
	if current then
		render()
		current.toggle()
	end
end

function CasebookController.close()
	local current = overlay
	if current then
		current.close()
	end
end

return CasebookController
