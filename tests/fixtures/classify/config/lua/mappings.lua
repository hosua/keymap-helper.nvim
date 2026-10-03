local map = vim.keymap.set
-- │ Files │
map("n", "<leader>ff", "<cmd>echo 1<cr>", { desc = "find files" })
map({ "n", "x" }, "<leader>fg", "<cmd>echo 2<cr>", { desc = "grep" })
-- │ Git │
map("n", "<leader>gs", "<cmd>echo 3<cr>", { desc = "status" })
map("n", "<leader>ia", "<cmd>echo dup<cr>", { desc = "dup of init" })
