Snippets to enhance neovim builtin undotree (https://github.com/neovim/neovim/pull/35627).

* Diff window (diff syntax or use gitsigns, with debounce delay).
* Switch on buffer change.
* Treesitter highlight.

```sh
nvim --cmd "set rtp^=. rtp+=./after undofile" README.md +'lua require"undotree-plus".open()' +'set winblend=20'
```

## credit
https://github.com/XXiaoA/atone.nvim
https://github.com/lewis6991/gitsigns.nvim
