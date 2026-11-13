-- ===== Опции =====
vim.opt.number = false
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.showmode = false
vim.opt.cmdheight = 1
vim.opt.laststatus = 2
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.autoread = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.scrolloff = 5
vim.opt.cursorline = true
vim.opt.signcolumn = "no"
vim.opt.whichwrap:append("<,>,[,]")

-- Выделение Shift + Стрелки
vim.opt.keymodel = "startsel,stopsel"
vim.opt.selection = "exclusive"
vim.opt.selectmode = ""

vim.opt.langmap = "ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ,фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz"

-- ===== Орфография и автодополнение =====
vim.opt.spelllang = { "en", "ru" }
vim.opt.spelloptions = "camel"
vim.opt.spellcapcheck = ""
vim.opt.complete = { ".", "w", "b", "u", "kspell" }
vim.opt.completeopt = { "menuone", "noselect", "popup", "fuzzy" }
vim.opt.pumheight = 10
pcall(function() vim.o.autocomplete = false end)

local text_ft = { text = true, markdown = true, gitcommit = true, tex = true, plaintex = true, rst = true }
vim.api.nvim_create_autocmd("BufEnter", {
    callback = function()
        if vim.bo.buftype == "" and vim.b.spell_init == nil then
            vim.b.spell_init = true
            if vim.bo.filetype == "" or text_ft[vim.bo.filetype] then vim.wo.spell = true end
        end
    end,
})

-- ===== Всегда в режиме вставки =====
vim.keymap.set("i", "<Esc>", "<Nop>")
local function can_insert()
    return vim.bo.buftype == "" and vim.bo.modifiable and vim.fn.mode() == "n"
end
vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter", "WinEnter" }, {
    callback = function() if can_insert() then vim.cmd("startinsert") end end,
})
vim.api.nvim_create_autocmd("ModeChanged", {
    pattern = "*:n",
    callback = function()
        vim.schedule(function() if can_insert() then vim.cmd("startinsert") end end)
    end,
})
vim.api.nvim_create_autocmd("InsertCharPre", {
    callback = function() vim.schedule(function() vim.o.hlsearch = false end) end,
})

-- ===== Мелкие удобства =====
vim.api.nvim_create_autocmd("TextYankPost", { callback = function() vim.hl.on_yank() end })
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, { command = "checktime" })
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, "\"")
        if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})
function _G.stl_spell() return vim.wo.spell and "SP  " or "" end
vim.opt.statusline = " [%n] %f %m%r%=%{v:lua.stl_spell()}%l:%c  %p%% "

-- ===== Сохранение настроек =====
local prefs = {}
local prefs_path = vim.fn.stdpath("data") .. "/user_prefs.json"
do
    local f = io.open(prefs_path, "r")
    if f then
        local ok, data = pcall(vim.json.decode, f:read("*a"))
        f:close()
        if ok and type(data) == "table" then prefs = data end
    end
end
local function save_prefs()
    local f = io.open(prefs_path, "w")
    if f then
        f:write(vim.json.encode(prefs))
        f:close()
    end
end

-- ===== Хелпер для шорткатов (латиница + русская раскладка) =====
local function map(lhs, ru, rhs, modes)
    modes = modes or { "i", "n" }
    vim.keymap.set(modes, "<C-" .. lhs .. ">", rhs, { silent = true })
    if ru then
        vim.keymap.set(modes, "<C-" .. ru .. ">", rhs, { silent = true })
    end
end
local function fmap(key, rhs)
    vim.keymap.set({ "i", "n" }, key, rhs, { silent = true })
end

-- Выделить всё
local function select_all()
    vim.cmd("stopinsert")
    vim.cmd("normal! ggVG")
end
map("a", "ф", select_all)

-- Вставка
map("v", "м", "<C-r><C-o>+", { "i" })
map("v", "м", "<C-r>+", { "c" })
map("]", nil, "<C-r><C-o>+", { "i" })
map("]", nil, "<C-r>+", { "c" })

-- Копировать / вырезать / вставить поверх выделения
map("c", "с", [["+y]], { "x" })
map("x", "ч", [["+d]], { "x" })
map("v", "м", [["+P]], { "x" })
map("]", nil, [["+P]], { "x" })
vim.keymap.set("x", "<BS>", [["_d]], { silent = true })
vim.keymap.set("x", "<Del>", [["_d]], { silent = true })

-- Отмена / повтор
map("z", "я", "<C-o>u", { "i" })
map("z", "я", "u", { "n" })
map("y", "н", "<C-o><C-r>", { "i" })
map("y", "н", "<C-r>", { "n" })

-- Сохранить
local function save_file()
    if vim.fn.expand("%") == "" then
        local cwd = vim.fn.getcwd()
        if not cwd:find("/$") then cwd = cwd .. "/" end
        local file = vim.fn.input("Сохранить как: ", cwd, "file")
        if file and file ~= "" then
            vim.cmd("write! " .. vim.fn.fnameescape(file))
        end
    else
        vim.cmd("write")
    end
end
map("s", "ы", save_file)

-- Выход
map("q", "й", function() vim.cmd("confirm quit") end)

-- ===== Файлы и буферы =====
map("n", "т", function() vim.cmd("enew") end)
map("o", "щ", function()
    local file = vim.fn.input("Открыть файл: ", vim.fn.getcwd() .. "/", "file")
    if file ~= "" then vim.cmd("edit " .. vim.fn.fnameescape(file)) end
end)
fmap("<A-w>", function() vim.cmd("confirm bdelete") end)
fmap("<C-PageDown>", function() vim.cmd("bnext") end)
fmap("<C-PageUp>", function() vim.cmd("bprevious") end)
fmap("<C-Tab>", function() vim.cmd("bnext") end)
fmap("<C-S-Tab>", function() vim.cmd("bprevious") end)

-- ===== Редактирование =====
-- Ctrl+Backspace / Ctrl+Delete: удалить слово
vim.keymap.set("i", "<C-BS>", "<C-w>", { silent = true })
vim.keymap.set("i", "<C-Del>", "<C-o>dw", { silent = true })

-- Дублировать / удалить строку
map("d", "в", function() vim.cmd("copy .") end)
map("k", "л", function() vim.cmd([[normal! "_dd]]) end)

-- Переместить строку Alt+Вверх/Вниз
local function move_line(d)
    local l, last = vim.fn.line("."), vim.fn.line("$")
    if (d < 0 and l == 1) or (d > 0 and l == last) then return end
    vim.cmd("move " .. (d < 0 and ".-2" or ".+1"))
end
fmap("<A-Up>", function() move_line(-1) end)
fmap("<A-Down>", function() move_line(1) end)
vim.keymap.set("x", "<A-Up>", ":move \39<-2<CR>gv", { silent = true })
vim.keymap.set("x", "<A-Down>", ":move \39>+1<CR>gv", { silent = true })

-- Комментирование Ctrl+/
vim.keymap.set("n", "<C-/>", "gcc", { remap = true, silent = true })
vim.keymap.set("n", "<C-_>", "gcc", { remap = true, silent = true })
vim.keymap.set("x", "<C-/>", "gc", { remap = true, silent = true })
vim.keymap.set("x", "<C-_>", "gc", { remap = true, silent = true })
vim.keymap.set("i", "<C-/>", function() vim.cmd("normal gcc") end, { silent = true })
vim.keymap.set("i", "<C-_>", function() vim.cmd("normal gcc") end, { silent = true })

-- Отступы в выделении
vim.keymap.set("x", "<Tab>", ">gv", { silent = true })
vim.keymap.set("x", "<S-Tab>", "<gv", { silent = true })

-- Движение по визуальным строкам (при переносе длинных строк)
vim.keymap.set("n", "<Down>", "gj", { silent = true })
vim.keymap.set("n", "<Up>", "gk", { silent = true })
vim.keymap.set("i", "<Down>", function()
    return vim.fn.pumvisible() == 1 and "<C-n>" or "<C-o>gj"
end, { expr = true, silent = true })
vim.keymap.set("i", "<Up>", function()
    return vim.fn.pumvisible() == 1 and "<C-p>" or "<C-o>gk"
end, { expr = true, silent = true })

-- ===== Автодополнение: Tab / Enter =====
vim.keymap.set("i", "<Tab>", function()
    return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })
vim.keymap.set("i", "<S-Tab>", function()
    return vim.fn.pumvisible() == 1 and "<C-p>" or "<C-d>"
end, { expr = true })
vim.keymap.set("i", "<CR>", function()
    if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected ~= -1 then
        return "<C-y>"
    end
    return "<CR>"
end, { expr = true })
vim.keymap.set("i", "<C-Space>", "<C-n>", { silent = true })

-- ===== Автозакрытие скобок и кавычек =====
local brackets = { ["("] = ")", ["["] = "]", ["{"] = "}" }
for open, close in pairs(brackets) do
    vim.keymap.set("i", open, function()
        local nxt = vim.api.nvim_get_current_line():sub(vim.fn.col("."), vim.fn.col("."))
        if nxt == "" or nxt:match("[%s%)%]}]") then return open .. close .. "<Left>" end
        return open
    end, { expr = true })
    vim.keymap.set("i", close, function()
        local nxt = vim.api.nvim_get_current_line():sub(vim.fn.col("."), vim.fn.col("."))
        if nxt == close then return "<Right>" end
        return close
    end, { expr = true })
end
for _, q in ipairs({ "\"", "\39", "`" }) do
    vim.keymap.set("i", q, function()
        local line, col = vim.api.nvim_get_current_line(), vim.fn.col(".")
        local prev, nxt = line:sub(col - 1, col - 1), line:sub(col, col)
        if nxt == q then return "<Right>" end
        local pb = prev:byte() or 0
        if pb >= 128 or prev:match("[%w_]") or prev == q then return q end
        if nxt == "" or nxt:match("[%s%)%]}]") then return q .. q .. "<Left>" end
        return q
    end, { expr = true })
end

-- ===== Поиск =====
local function search(dir)
    vim.o.hlsearch = true
    local pre = vim.fn.mode() == "i" and "<C-o>" or ""
    vim.api.nvim_feedkeys(vim.keycode(pre .. dir), "nt", false)
end
local function find_next(back)
    vim.o.hlsearch = true
    pcall(vim.cmd, "normal! " .. (back and "N" or "n"))
end
map("f", "а", function() search("/") end)
fmap("<F3>", function() find_next(false) end)
fmap("<S-F3>", function() find_next(true) end)

-- Найти и заменить (с подтверждением каждой замены)
local function replace_all()
    local bs = string.char(92)
    local from = vim.fn.input("Найти: ")
    if from == "" then return end
    local to = vim.fn.input("Заменить на: ")
    local e1 = vim.fn.escape(from, "/" .. bs)
    local e2 = vim.fn.escape(to, "/" .. bs .. "&")
    vim.cmd("%s/" .. bs .. "V" .. e1 .. "/" .. e2 .. "/gc")
end
fmap("<F6>", replace_all)

-- ===== Переход к строке =====
local function goto_line()
    local n = tonumber(vim.fn.input("Перейти к строке: "))
    if n then
        n = math.max(1, math.min(math.floor(n), vim.fn.line("$")))
        vim.api.nvim_win_set_cursor(0, { n, 0 })
        vim.cmd("normal! zz")
    end
end
map("g", "п", goto_line)

-- ===== Орфография =====
fmap("<F7>", function()
    vim.wo.spell = not vim.wo.spell
    vim.notify("Орфография: " .. (vim.wo.spell and "вкл" or "выкл"))
end)
fmap("<F8>", function() vim.cmd("normal! [sz=") end)
fmap("<F9>", function()
    local ok = pcall(function() vim.o.autocomplete = not vim.o.autocomplete end)
    vim.notify(ok and ("Автодополнение: " .. (vim.o.autocomplete and "вкл" or "выкл")) or "Нет опции autocomplete")
end)
fmap("<F5>", function() vim.wo.number = not vim.wo.number end)

-- ===== Тема =====
if prefs.theme then pcall(vim.cmd.colorscheme, prefs.theme) end
local function select_theme()
    local choice = vim.fn.input("Тема (Tab - список): ", "", "color")
    if choice ~= "" then
        if pcall(vim.cmd.colorscheme, choice) then
            prefs.theme = choice
            save_prefs()
        else
            vim.notify("Нет такой темы: " .. choice, vim.log.levels.WARN)
        end
    end
end
map("t", "е", select_theme)
fmap("<F2>", select_theme)

-- ===== Эффекты курсора (Neovide) =====
local function set_vfx(name)
    vim.g.neovide_cursor_vfx_mode = (name == "off" or prefs.profile == "classic") and "" or name
end
local function select_vfx()
    local modes = { "pixiedust", "railgun", "torpedo", "wireframe", "sonicboom", "ripple", "off" }
    vim.ui.select(modes, { prompt = "Выберите эффект частиц:" }, function(choice)
        if choice then
            set_vfx(choice)
            prefs.vfx = choice; if prefs.profile == "classic" and choice ~= "off" then prefs.profile = "fancy" end; if _G.apply_profile then _G.apply_profile() end
            save_prefs()
        end
    end)
end
map("e", "у", select_vfx)
fmap("<F4>", select_vfx)

-- ===== Размер шрифта =====
local font_size = prefs.fontsize or 13
local function apply_font()
    if vim.g.neovide then vim.o.guifont = "JetBrainsMono Nerd Font:h" .. font_size end
end
local function zoom(d)
    font_size = d == 0 and 13 or math.max(6, math.min(48, font_size + d))
    prefs.fontsize = font_size
    save_prefs()
    apply_font()
end
map("=", nil, function() zoom(1) end)
map("-", nil, function() zoom(-1) end)
map("0", nil, function() zoom(0) end)
fmap("<C-kPlus>", function() zoom(1) end)
fmap("<C-kMinus>", function() zoom(-1) end)
fmap("<C-ScrollWheelUp>", function() zoom(1) end)
fmap("<C-ScrollWheelDown>", function() zoom(-1) end)

-- ===== Справка по шорткатам (F1) =====
local help_lines = {
    " Файл          Ctrl+S сохранить   Ctrl+O открыть   Ctrl+N новый   Ctrl+Q выход ",
    " Буферы        Ctrl+PgUp/PgDn или Ctrl+Tab переключить   Alt+W закрыть ",
    " Правка        Ctrl+Z отмена   Ctrl+Y повтор   Ctrl+A всё ",
    "               Ctrl+C / X / V копировать / вырезать / вставить ",
    "               Ctrl+D дублировать строку   Ctrl+K удалить строку ",
    "               Alt+Вверх/Вниз переместить строку   Ctrl+/ комментарий ",
    "               Ctrl+Backspace удалить слово   Tab/Shift+Tab отступ ",
    " Поиск         Ctrl+F поиск   F3 / Shift+F3 далее / назад ",
    "               F6 найти и заменить   Ctrl+G перейти к строке ",
    " Дополнение    Tab / Shift+Tab выбор   Enter принять   Ctrl+Space вызвать ",
    "               F9 вкл/выкл автодополнение ",
    " Орфография    F7 вкл/выкл   F8 исправить слово ",
    " Вид           F2 / Ctrl+T тема   F4 / Ctrl+E эффект   F5 номера строк ",
    "               Ctrl+= / Ctrl+- / Ctrl+0 размер шрифта (или Ctrl+колесо) ",
    "               F11 полный экран   F10 режим   F1 справка ",
}
local function show_help()
    vim.cmd("stopinsert")
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
    local w = 0
    for _, l in ipairs(help_lines) do w = math.max(w, vim.fn.strdisplaywidth(l)) end
    local h = #help_lines
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor", width = w, height = h,
        row = math.max(0, math.floor((vim.o.lines - h) / 2) - 1),
        col = math.max(0, math.floor((vim.o.columns - w) / 2)),
        style = "minimal", border = "rounded", title = " Шорткаты ", title_pos = "center",
    })
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    for _, k in ipairs({ "q", "<Esc>", "<CR>", "<F1>" }) do
        vim.keymap.set("n", k, function() pcall(vim.api.nvim_win_close, win, true) end, { buffer = buf })
    end
end
fmap("<F1>", show_help)

-- ===== Neovide =====
local function apply_profile()
    local classic = prefs.profile == "classic"
    if classic then
        vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver40-blinkwait700-blinkoff400-blinkon400,r-cr-o:hor30"
    else
        vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
    end
    if not vim.g.neovide then return end
    if classic then
        vim.g.neovide_cursor_vfx_mode = ""
        vim.g.neovide_cursor_animation_length = 0
        vim.g.neovide_cursor_trail_size = 0
        vim.g.neovide_cursor_smooth_blink = false
        vim.g.neovide_cursor_animate_in_insert_mode = false
        vim.g.neovide_cursor_animate_command_line = false
        vim.g.neovide_scroll_animation_length = 0
        vim.g.neovide_scroll_animation_far_lines = 0
        vim.g.neovide_position_animation_length = 0
        vim.g.neovide_opacity = 1.0
    else
        set_vfx(prefs.vfx or "pixiedust")
        vim.g.neovide_cursor_vfx_opacity = 200.0
        vim.g.neovide_cursor_vfx_particle_lifetime = 1.2
        vim.g.neovide_cursor_vfx_particle_density = 10.0
        vim.g.neovide_cursor_animation_length = 0.15
        vim.g.neovide_cursor_trail_size = 0.8
        vim.g.neovide_cursor_smooth_blink = true
        vim.g.neovide_cursor_animate_in_insert_mode = true
        vim.g.neovide_cursor_animate_command_line = true
        vim.g.neovide_scroll_animation_length = 0.25
        vim.g.neovide_scroll_animation_far_lines = 1
        vim.g.neovide_position_animation_length = 0.15
        vim.g.neovide_opacity = 0.80
    end
    apply_font()
end
_G.apply_profile = apply_profile

local function toggle_profile()
    prefs.profile = (prefs.profile == "classic") and "fancy" or "classic"
    save_prefs()
    apply_profile()
    vim.notify("Режим: " .. (prefs.profile == "classic" and "классика" or "с эффектами"))
end
fmap("<F10>", toggle_profile)

if vim.g.neovide then
    vim.g.neovide_hide_mouse_when_typing = true
    vim.g.neovide_padding_top = 6
    vim.g.neovide_padding_bottom = 6
    vim.g.neovide_padding_left = 10
    vim.g.neovide_padding_right = 10
    fmap("<F11>", function() vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen end)
end
apply_profile()
