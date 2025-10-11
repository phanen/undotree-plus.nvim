Snippets to enhance neovim builtin undotree (https://github.com/neovim/neovim/pull/35627).

* Diff window (simple diff filetype or use gitsigns).
* Switch on buffer change.
* Treesitter highlight.

```sh
nvim --cmd "set rtp^=. rtp+=./after undofile" README.md +'lua require"undotree-plus".open()' +'set winblend=20'
```

## credit
https://github.com/XXiaoA/atone.nvim
