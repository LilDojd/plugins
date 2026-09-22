--- @since 26.8.15

local WINDOWS = ya.target_family() == "windows"

---@enum DiffType
local DiffType = {
	conflicted = 6,
	modified = 5,
	added = 4,
	deleted = 3,
	renamed = 1,
}

local CODES = {
	conflicted = DiffType.conflicted,
	modified = DiffType.modified,
	added = DiffType.added,
	removed = DiffType.deleted,
	copied = DiffType.added,
	renamed = DiffType.renamed,
}

-- Raw, NUL-delimited paths avoid quoting, whitespace, and rename-display ambiguity.
-- Include inherited conflicts, which need not appear in the working-copy diff.
local TEMPLATE =
	[[diff.files().map(|f| f.status() ++ "\0" ++ f.path() ++ "\0").join("") ++ conflicted_files.map(|f| "conflicted\0" ++ f.path() ++ "\0").join("")]]

local function theme()
	local t = th.jj or {}
	return {
		[DiffType.conflicted] = t.conflicted or ui.Style():fg("red"):bold(),
		[DiffType.renamed] = t.renamed or ui.Style():fg("cyan"),
		[DiffType.modified] = t.modified or ui.Style():fg("yellow"),
		[DiffType.added] = t.added or ui.Style():fg("green"),
		[DiffType.deleted] = t.deleted or ui.Style():fg("red"),
	}, {
		[DiffType.conflicted] = t.conflicted_sign or "🞩",
		[DiffType.renamed] = t.renamed_sign or "",
		[DiffType.modified] = t.modified_sign or "",
		[DiffType.added] = t.added_sign or "",
		[DiffType.deleted] = t.deleted_sign or "",
	}
end

---@param cwd Url
---@return string?
local function root(cwd)
	repeat
		local stat = (fs.stat or fs.cha)(cwd:join(".jj"))
		if stat and stat.is_dir then
			return tostring(cwd)
		end
		cwd = cwd.parent
	until not cwd
end

local function retry(job)
	return ya.co(function()
		for _, file in ipairs(job.files) do
			coroutine.yield(file, { retry = true })
		end
	end)
end

---@param changed table<string, DiffType>
local function bubble_up(changed)
	local dirs, empty = {}, Url("")
	for path, code in pairs(changed) do
		local url = Url(path).parent
		while url and url ~= empty do
			local s = tostring(url)
			local previous = dirs[s]
			if previous == DiffType.conflicted or code == DiffType.conflicted then
				dirs[s] = DiffType.conflicted
			elseif previous and previous ~= code then
				dirs[s] = DiffType.modified
			else
				dirs[s] = code
			end
			url = url.parent
		end
	end
	ya.dict_merge(changed, dirs)
end

local add = ya.sync(function(st, cwd, repo, changed)
	st.dirs[cwd] = repo
	-- Replace the snapshot so resolved conflicts and removed paths cannot linger.
	st.repos[repo] = changed
	ui.render()
end)

local remove = ya.sync(function(st, cwd)
	local repo = st.dirs[cwd]
	if not repo then
		return
	end

	st.dirs[cwd] = nil
	ui.render()
	for _, r in pairs(st.dirs) do
		if r == repo then
			return
		end
	end
	st.repos[repo] = nil
end)

local function setup(st, opts)
	st.dirs = {}
	st.repos = {}

	local styles, signs = theme()
	ps.sub("theme", function()
		styles, signs = theme()
	end)

	Linemode:children_add(function(self)
		if not self._file.in_current then
			return ""
		end

		local url = self._file.url
		local repo = st.dirs[tostring(url.base or url.parent)]
		local code = repo and st.repos[repo][tostring(url:strip_prefix(Url(repo)))]
		if not code or signs[code] == "" then
			return ""
		elseif self._file.is_hovered then
			return ui.Line { " ", signs[code] }
		else
			return ui.Line { " ", ui.Span(signs[code]):style(styles[code]) }
		end
	end, (opts or {}).order or 1500)
end

local function fetch(_, job)
	local first = job.files[1]
	if not first or not first.url.spec.is_regular then
		return require("noop"):fetch(job)
	end

	local cwd = first.url.base or first.url.parent
	local repo = cwd and root(cwd)
	if not repo then
		remove(tostring(cwd))
		return require("noop"):fetch(job)
	end

	local output, err = Command("jj")
		:cwd(repo)
		:arg({ "--no-pager", "--color", "never", "log", "--no-graph", "-r", "@", "-T", TEMPLATE })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()
	if not output then
		ya.err("Cannot spawn `jj`: " .. tostring(err))
		return retry(job)
	elseif not output.status.success then
		ya.err("`jj log` failed: " .. output.stderr)
		return retry(job)
	end

	local changed = {}
	for kind, path in output.stdout:gmatch("([^%z]+)%z([^%z]+)%z") do
		if WINDOWS then
			path = path:gsub("/", "\\")
		end
		changed[path] = CODES[kind]
	end
	bubble_up(changed)
	add(tostring(cwd), repo, changed)
	return retry(job)
end

return { setup = setup, fetch = fetch }
